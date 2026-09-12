-- The deck learns from a swipe (D136).
--
-- Nothing in the app read a swipe back into the ranking. The taste term asked
-- one question -- is this cuisine one of the ones picked during onboarding --
-- so somebody who picked "Western" on day one and has passed on every Western
-- place since still gets Western, and the swipes that said otherwise went
-- nowhere.
--
-- The fix is a per-cuisine like rate shrunk toward that onboarding pick:
--
--     p_like = (likes + 2 * prior) / (swipes + 2)
--
-- with prior 1.0 for a picked cuisine and 0.0 for the rest. The degenerate
-- prior is the point. The obvious softer version -- 0.65 and 0.35 -- spans
-- 0.045 of the total score, inside the jitter's shadow even after D137 halved
-- it, so the onboarding pick would have quietly stopped mattering the day
-- this shipped. At 1.0 and 0.0 a user with no swipes in a cuisine scores
-- exactly as they did yesterday, and evidence moves the cuisine from there.
--
-- Only deck swipes count. A "Set a date" like (D112) and a Nearby-map swipe
-- are not deck exposures; counting them would rate a cuisine on cards the
-- deck never dealt.
--
-- The indiscriminate swiper needs no code. Somebody who likes nine cards in
-- ten lands every cuisine near its own prior, which is where the shrinkage
-- puts them anyway.
--
-- Honest about the day it ships: 63 deck swipes across one profile is nearly
-- inert. The alternative is never starting to learn.
--
-- `rows 1600` rather than the `rows 300` this file inherited: D142 raised the
-- estimate to something near the truth, and the two `create or replace`
-- statements between here and there carried the stale number forward. Both
-- are corrected in place in the same commit so a replay from empty lands
-- where the live database already is.

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
language sql stable rows 1600 set search_path = '' as $function$
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
  affinity as (
    -- D136. A per-cuisine like rate, shrunk toward the onboarding pick by a
    -- pseudo-count of 2. The prior is degenerate on purpose: 1.0 for a picked
    -- cuisine, 0.0 otherwise, which is exactly what `matches_pick` was, so a
    -- user with no swipes in a cuisine gets today's deck to the row. Evidence
    -- then moves it at the rate the pseudo-count allows -- two likes barely
    -- shift a picked cuisine, two passes pull it to 0.5. That shrinkage is
    -- the whole of the cold-start handling; there is no new-user branch.
    -- `source = 'deck'` only: a "Set a date" like (D112) and a map swipe are
    -- not deck exposures and would poison the rate. The denominator counts
    -- restaurants rather than swipe events because `record_swipe` upserts.
    select
      rc.cuisine_id,
      (sum(case when s.liked then 1 else 0 end)
        + 2.0 * (case when exists (
            select 1
            from public.profile_cuisines pc
            where pc.profile_id = (select auth.uid())
              and pc.cuisine_id = rc.cuisine_id
          ) then 1.0 else 0.0 end))
      / (count(*) + 2.0) as p_like
    from public.swipes s
    join public.restaurant_cuisines rc on rc.restaurant_id = s.restaurant_id
    where s.user_id = (select auth.uid())
      and s.source = 'deck'
    group by rc.cuisine_id
  ),
  taste as (
    select
      rc.restaurant_id,
      -- the learned rate when this user has swiped the cuisine, the
      -- onboarding pick when they have not
      max(coalesce(a.p_like,
                   case when pc.cuisine_id is not null then 1 else 0 end))
        as pick_score,
      max(case when cu.is_breakfast then 1 else 0 end) as breakfasty,
      max(cu.spice_level) as spice_level
    from public.restaurant_cuisines rc
    join public.cuisines cu on cu.id = rc.cuisine_id and cu.is_active
    left join public.profile_cuisines pc
      on pc.cuisine_id = rc.cuisine_id
     and pc.profile_id = (select auth.uid())
    left join affinity a on a.cuisine_id = rc.cuisine_id
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
        0.60 * coalesce(t.pick_score, 0)
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
