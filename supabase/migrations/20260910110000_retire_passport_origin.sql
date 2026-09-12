-- D84 retired passport. The columns kept winning anyway.
--
-- `deck_scored` and `search_restaurants` both resolved their origin as
-- `coalesce(passport, argument, last_fix)`, so a pin left behind before the
-- feature was removed silently outranked the device. One live profile was
-- being dealt a deck within 15 km of a pin 25 km from the town its own header
-- named, with the card distances measured from somewhere else again — three
-- origins on one screen, none of them wrong on their own.
--
-- The chain is now `argument, else the stored fix`, which is what the client
-- measures from too. `set_passport` goes with it: nothing in the app has
-- called it since D84, and a writer for a feature that does not exist is the
-- thing D84 says to delete.
--
-- The columns are left in place. Dropping user data is a separate decision
-- from ignoring it, and nothing reads them now.

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
      s.created_at as swiped_at,
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
          and public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
              <= c.radius_km
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
    + (0.35 + case when ranked.rating > 0 then 0 else 0.15 end)
      * public.deck_jitter(ranked.id, ranked.seed)
    as score,
    ranked.km,
    ranked.swiped_at,
    ranked.liked
  from ranked
  left join taste t on t.restaurant_id = ranked.id
  left join diet d on d.restaurant_id = ranked.id;
$function$;

create or replace function public.search_restaurants(
  p_query text default null,
  p_limit integer default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km integer default null,
  p_cuisine_id bigint default null
) returns setof public.restaurants
language sql stable set search_path = '' as $function$
  with me as (
    select p.* from public.profiles p where p.id = (select auth.uid())
  ),
  ctx as (
    select
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng,
      coalesce(p_radius_km, (select m.search_radius_km from me m)) as radius_km,
      nullif(btrim(coalesce(p_query, '')), '') as q
  )
  select r.*
  from public.restaurants r
  cross join ctx c
  where r.is_active
    and (
      c.q is null
      or r.search @@ pg_catalog.websearch_to_tsquery('simple', c.q)
      -- a two-letter prefix ('na' for nasi) never matches a tsquery term, so
      -- fall back to a plain contains match for short/partial input
      or r.name ilike '%' || c.q || '%'
    )
    and (
      p_cuisine_id is null
      or exists (
        select 1
        from public.restaurant_cuisines rc
        where rc.restaurant_id = r.id
          and rc.cuisine_id = p_cuisine_id
      )
    )
    and (
      c.radius_km is null or c.lat is null or c.lng is null
      or (
        (r.latitude <> 0 or r.longitude <> 0)
        and public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
            <= c.radius_km
      )
    )
  order by
    case
      when c.q is null then 0
      else -pg_catalog.ts_rank(r.search, pg_catalog.websearch_to_tsquery('simple', c.q))
    end,
    case
      when c.lat is null or (r.latitude = 0 and r.longitude = 0) then 1e9
      else public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
    end,
    r.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$function$;

drop function if exists public.set_passport(double precision, double precision, text);
