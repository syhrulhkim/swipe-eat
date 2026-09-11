-- Cuisine diversity, and half the jitter it was standing in for (D137).
--
-- `get_deck` could hand back five satay stalls in a row. Proximity dominates
-- the score, satay stalls cluster geographically, and the jitter is per
-- restaurant rather than per position, so it could not break up a run — it
-- could only make the run a different run each day.
--
-- The fix is a soft penalty on the serve order: the nth card of a cuisine
-- loses 0.02 × (n − 1). Not a round-robin, which would be wrong here — 22
-- cuisines are in use against a 30-card deck, so partitioning would hand
-- nearly every cuisine exactly one slot and give the cuisine the user
-- demonstrably likes no more room than the one they do not.
--
-- 0.02 rather than the 0.05 this was planned at, because the plan guessed and
-- then it was measured. The top sixty candidates of a real 30 km deck span
-- 0.211 of score, so 0.05 pushes a cuisine's fifth card below the sixtieth
-- best card outright — a round-robin in all but name, and it would cancel the
-- affinity term (D136) before that shipped. Over the same deck: no penalty
-- leaves runs of 3 and 10 cuisines in thirty cards; 0.02 leaves no run longer
-- than 1 and 14 cuisines; 0.05 reaches 18 and buys nothing the user can feel.
-- 0.02 also leaves a liked cuisine about eight cards before the penalty eats
-- the edge affinity gives it.
--
-- `restaurant_cuisines` is many-to-many and carries no position column. No
-- active restaurant holds more than one cuisine today (1,605 of 1,605 hold
-- exactly one), so "the" cuisine is unambiguous; `min(cuisine_id)` keeps the
-- query correct the day that stops being true.
--
-- Then the jitter halves, 0.50 to 0.25. Most of what it bought was exactly
-- this anti-clustering, bought blindly. The order matters: cutting the jitter
-- first would have exposed the clustering it was hiding.

create or replace function public.deck_scored(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_seed bigint default null,
  p_radius_km integer default null,
  p_local_hour integer default null
) returns table(
  restaurant_id bigint,
  score double precision,
  distance_km double precision,
  swiped_at timestamp with time zone,
  liked boolean
)
language sql stable rows 300 set search_path = '' as $function$
  with me as (
    select p.*
    from public.profiles p
    where p.id = (select auth.uid())
  ),
  ctx as (
    select
      -- the device fix beats the stored last location; passport is gone (D84)
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng,
      -- an explicit argument wins; otherwise the Settings value; null = no limit
      coalesce(p_radius_km, (select m.search_radius_km from me m)) as radius_km,
      coalesce((select m.morning_mode from me m), true) as morning_mode,
      coalesce((select m.spice_bias from me m), 'medium') as spice_bias,
      coalesce((select m.nearby_focus from me m), true) as nearby_focus,
      coalesce((select m.halal_only from me m), false) as halal_only,
      coalesce((select m.vegetarian from me m), false) as vegetarian,
      (select m.budget_max from me m) as budget_max,
      coalesce((select m.filter_cuisine_ids from me m),
               '{}'::bigint[]) as f_cuisines,
      coalesce((select m.filter_dietary_tag_ids from me m),
               '{}'::bigint[]) as f_diet,
      (select m.filter_min_rating from me m) as f_min_rating,
      coalesce(
        p_seed,
        pg_catalog.hashtext(
          coalesce((select auth.uid())::text, 'anon') || ':' ||
          (pg_catalog.now() at time zone 'Asia/Kuala_Lumpur')::date::text
        )::bigint
      ) as seed,
      coalesce(
        p_local_hour,
        pg_catalog.date_part('hour', pg_catalog.now() at time zone 'Asia/Kuala_Lumpur')::int
      ) as local_hour
  ),
  candidates as (
    select
      r.id,
      r.rating,
      r.video_url,
      s.updated_at as swiped_at,
      s.liked,
      case
        when c.lat is null or c.lng is null then null
        when r.latitude = 0 and r.longitude = 0 then null
        else public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
      end as km,
      c.*
    from public.restaurants r
    cross join ctx c
    left join public.swipes s
      on s.restaurant_id = r.id and s.user_id = (select auth.uid())
    where r.is_active
      and (
        -- no radius, or nowhere to measure from: everything stays in play
        c.radius_km is null or c.lat is null or c.lng is null
        or (
          (r.latitude <> 0 or r.longitude <> 0)
          and (
        -- The box before the circle (D141). 110.5 km is the shortest a degree
        -- of latitude ever gets, so the box is always wider than the circle:
        -- it can admit a row haversine then drops, never drop one haversine
        -- would have kept. The longitude span is taken at the far edge of the
        -- box, where a degree is narrowest.
        -- ponytail: no antimeridian wrap, the catalogue is Malaysian.
        r.latitude between c.lat - c.radius_km::double precision / 110.5
                       and c.lat + c.radius_km::double precision / 110.5
        and r.longitude between c.lng - c.radius_km::double precision / (110.5 * greatest(cos(radians(least(abs(c.lat) + c.radius_km::double precision / 110.5, 89.9))), 0.01))
                            and c.lng + c.radius_km::double precision / (110.5 * greatest(cos(radians(least(abs(c.lat) + c.radius_km::double precision / 110.5, 89.9))), 0.01))
        and public.haversine_km(c.lat, c.lng, r.latitude, r.longitude) <= c.radius_km
      )
        )
      )
      -- halal only: a hard rule, so an *unknown* certification is not good
      -- enough. Most of the catalogue is unknown, which is exactly why this
      -- is off by default rather than on (D105).
      and (not c.halal_only or r.is_halal is true)
      -- vegetarian: the place must carry the tag, matched by slug so the
      -- predicate does not depend on a seeded id.
      and (
        not c.vegetarian
        or exists (
          select 1
          from public.restaurant_dietary_tags rdt
          join public.dietary_tags dt on dt.id = rdt.dietary_tag_id
          where rdt.restaurant_id = r.id
            and dt.slug = 'vegetarian'
        )
      )
      -- budget ceiling. An unknown price passes: price_from is null for most
      -- rows, and dropping them would empty the deck for anyone who answered
      -- the budget question at all (D105).
      and (
        c.budget_max is null
        or r.price_from is null
        or r.price_from <= c.budget_max
      )
      -- cuisine filter: any of the picked cuisines qualifies
      and (
        pg_catalog.cardinality(c.f_cuisines) = 0
        or exists (
          select 1 from public.restaurant_cuisines rc
          where rc.restaurant_id = r.id
            and rc.cuisine_id = any (c.f_cuisines)
        )
      )
      -- dietary filter: every picked tag must be satisfied — these are
      -- restrictions, not preferences, so "vegetarian and halal" means both
      and (
        pg_catalog.cardinality(c.f_diet) = 0
        or not exists (
          select 1 from pg_catalog.unnest(c.f_diet) as want(tag_id)
          where not exists (
            select 1 from public.restaurant_dietary_tags rdt
            where rdt.restaurant_id = r.id
              and rdt.dietary_tag_id = want.tag_id
          )
        )
      )
      -- minimum rating. Unrated rows (rating 0) fall out too: a filter that
      -- quietly kept them would not be a filter.
      and (c.f_min_rating is null or r.rating >= c.f_min_rating)
  ),
  taste as (
    select
      rc.restaurant_id,
      max(case when pc.cuisine_id is not null then 1 else 0 end) as matches_pick,
      max(case when cu.is_breakfast then 1 else 0 end) as breakfasty,
      max(cu.spice_level) as spice_level
    from public.restaurant_cuisines rc
    join public.cuisines cu on cu.id = rc.cuisine_id and cu.is_active
    left join public.profile_cuisines pc
      on pc.cuisine_id = rc.cuisine_id
     and pc.profile_id = (select auth.uid())
    group by rc.restaurant_id
  ),
  diet as (
    select rdt.restaurant_id, 1 as matches
    from public.restaurant_dietary_tags rdt
    join public.profile_dietary_tags pdt
      on pdt.dietary_tag_id = rdt.dietary_tag_id
     and pdt.profile_id = (select auth.uid())
    group by rdt.restaurant_id
  ),
  ranked as (
    select
      cand.*,
      -- rank percentile, not raw value: immune to gaps between video ids
      percent_rank() over (
        order by coalesce(public.tiktok_video_id(cand.video_url), 0), cand.id
      ) as freshness
    from candidates cand
  )
  select
    ranked.id,
    -- proximity: 1.0 at 0 km, 0.5 at 12 km, ~0 far away. Unknown location gets
    -- neutral half credit so an ungeocoded row is not locked out of the front.
    0.30 * (case when ranked.nearby_focus then 1.5 else 1.0 end)
         * (case
              when ranked.lat is null then 0
              when ranked.km is null then 0.5
              else power(2, -ranked.km / 12.0)
            end)
    + 0.20 * ranked.freshness
    -- 283 of 288 rows are unrated: scoring them all as 0 would flatten the
    -- signal, so an unrated row hands its weight to exploration instead.
    + (case when ranked.rating > 0 then 0.15 * least(ranked.rating, 5) / 5.0
            else 0 end)
    + 0.25 * (
        0.60 * coalesce(t.matches_pick, 0)
        + (case
             when ranked.morning_mode and ranked.local_hour < 11
                  and coalesce(t.breakfasty, 0) = 1 then 0.25
             else 0
           end)
        + 0.15 * (case
                    when t.spice_level is null then 0
                    else greatest(0, 1 - abs(
                      t.spice_level - case ranked.spice_bias
                                        when 'low' then 0
                                        when 'medium' then 1
                                        else 2
                                      end
                    ) / 2.0)
                  end)
      )
    + 0.10 * coalesce(d.matches, 0)
    + (0.175 + case when ranked.rating > 0 then 0 else 0.075 end)
      * public.deck_jitter(ranked.id, ranked.seed)
    as score,
    ranked.km,
    ranked.swiped_at,
    ranked.liked
  from ranked
  left join taste t on t.restaurant_id = ranked.id
  left join diet d on d.restaurant_id = ranked.id;
$function$;

create or replace function public.get_deck(
  p_limit integer default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_seed bigint default null,
  p_radius_km integer default null,
  p_local_hour integer default null
)
returns setof public.restaurants
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
begin
  return query
    with scored as materialized (
      -- Once. Every bucket reads this, and `materialized` is what guarantees
      -- the ranker is not run a second time to answer the second one (D142).
      select d.restaurant_id, d.score, d.swiped_at, d.liked
      from public.deck_scored(
        p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour
      ) d
    ),
    cuisine_of as (
      -- No active restaurant carries more than one cuisine today, so this is
      -- "the" cuisine. `min` keeps it single-valued the day that changes.
      select rc.restaurant_id, min(rc.cuisine_id) as cuisine_id
      from public.restaurant_cuisines rc
      group by rc.restaurant_id
    ),
    -- Bucket 0 is a card nobody has seen. Bucket 1 is deck exhaustion: the
    -- catalogue goes fast, so rather than show an empty deck, resurface passes
    -- older than three days — the retention the device-local
    -- SeenRestaurantsStore used, measured from the last swipe (D135). Likes
    -- never come back: they live in the Bites tab, and re-showing them reads
    -- as a bug.
    served as (
      select
        s.restaurant_id,
        (case when s.swiped_at is null then 0 else 1 end) as bucket,
        -- The nth card of a cuisine loses 0.02 × (n − 1), counted over every
        -- candidate rather than over the thirty that fit, so the penalty
        -- decides which thirty those are (D137).
        s.score - 0.02 * (row_number() over (
          partition by (case when s.swiped_at is null then 0 else 1 end),
                       coalesce(c.cuisine_id, 0)
          order by s.score desc, s.restaurant_id
        ) - 1) as score
      from scored s
      left join cuisine_of c on c.restaurant_id = s.restaurant_id
      where s.swiped_at is null
         or (
           s.liked is false
           and s.swiped_at < pg_catalog.now() - interval '3 days'
         )
    ),
    -- `bucket` first, so a card nobody has seen always beats a card coming
    -- back, and the resurfaced ones only ever fill what is left of the limit.
    picked as (
      select v.restaurant_id, v.bucket, v.score
      from served v
      order by v.bucket, v.score desc, v.restaurant_id
      limit v_limit
    )
    -- The columns are joined back *after* the limit: thirty wide rows, not
    -- the whole catalogue (D142).
    select r.*
    from picked p
    join public.restaurants r on r.id = p.restaurant_id
    order by p.bucket, p.score desc, p.restaurant_id;
end
$$;
