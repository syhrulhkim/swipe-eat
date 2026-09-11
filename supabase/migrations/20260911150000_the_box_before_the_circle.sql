-- Distance stops being a full scan (D141).
--
-- There is no geographic index of any kind in this project: no PostGIS, no
-- earthdistance, no cube, no GiST. `haversine_km` is a function call in a
-- `where` clause, which is not sargable, so every distance filter reads the
-- whole catalogue and evaluates trigonometry on every row — in `deck_scored`
-- and again in `get_nearby`.
--
-- The cheap version of the same idea, and the one D9 left room for: filter by
-- a bounding box first, which an ordinary btree can answer, and keep haversine
-- as the exact test inside the box. The box is deliberately generous — it uses
-- 110.5 km per degree of latitude, the smallest a degree ever gets, and takes
-- the longitude span at the far edge of the box where a degree is narrowest —
-- so it can only ever admit a row the circle then rejects. It can never drop
-- one the circle would have kept, which is the only failure that would matter.
--
-- Measured on the live project, 1,607 active rows, twenty warm calls each:
--
--   get_nearby(3 km)     15.41 ms -> 5.66 ms
--   get_deck(30 km)      26.89 ms -> 25.10 ms
--   get_deck(500 km)     28.00 ms -> 32.13 ms
--
-- The map is the win, because its whole answer is the circle. The deck barely
-- moves, because ranking — percent_rank, the taste and diet joins — is most of
-- its work either way. At 500 km the box covers the catalogue and the planner
-- takes the index anyway, so it pays for a scan it cannot narrow; no radius
-- the app offers is anywhere near that, and a null radius skips the predicate
-- entirely. In isolation the distance filter alone goes 3.99 ms -> 0.49 ms at
-- 30 km, with 1,087 rows removed by filter becoming 12.
--
-- Correctness was checked before the index could matter: 120 random origins
-- across the region at random radii, comparing the function's row count
-- against a raw haversine count over `restaurants`. Zero mismatches.

-- Partial, because every caller of both functions filters on is_active.
create index if not exists restaurants_active_lat_lng_idx
  on public.restaurants (latitude, longitude)
  where is_active;

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

create or replace function public.get_nearby(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 3,
  p_limit int default 60
)
returns table (
  id bigint,
  name text,
  tag text,
  details text,
  brand_color text,
  rating numeric,
  latitude double precision,
  longitude double precision,
  video_url text,
  hours_text text,
  opens_at time without time zone,
  closes_at time without time zone,
  closed_dow smallint[],
  price_from integer,
  is_halal boolean,
  neighbourhood text,
  restaurant_images jsonb,
  dishes jsonb,
  reviews jsonb,
  distance_km double precision,
  open_now boolean,
  swiped boolean
)
language sql
stable
set search_path to ''
as $function$
  with me as (
    select p.*
    from public.profiles p
    where p.id = (select auth.uid())
  ),
  ctx as (
    select
      -- An explicit fix wins; otherwise the profile's stored coordinates, so
      -- a user who denied location still gets a map around their last known
      -- position rather than an empty one.
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng,
      -- Never zero or negative: a radius of 0 would return nothing and read
      -- as "there is no food here".
      greatest(coalesce(p_radius_km, 3), 0.1) as radius_km,
      coalesce((select m.halal_only from me m), false) as halal_only,
      coalesce((select m.vegetarian from me m), false) as vegetarian,
      (select m.budget_max from me m) as budget_max,
      coalesce((select m.filter_cuisine_ids from me m),
               '{}'::bigint[]) as f_cuisines,
      coalesce((select m.filter_dietary_tag_ids from me m),
               '{}'::bigint[]) as f_diet,
      (select m.filter_min_rating from me m) as f_min_rating
  )
  select
    r.id,
    r.name,
    r.tag,
    r.details,
    r.brand_color,
    r.rating,
    r.latitude,
    r.longitude,
    r.video_url,
    r.hours_text,
    r.opens_at,
    r.closes_at,
    r.closed_dow,
    r.price_from,
    r.is_halal,
    r.neighbourhood,
    coalesce(
      (
        select pg_catalog.jsonb_agg(
                 pg_catalog.jsonb_build_object(
                   'url', ri.url,
                   'position', ri.position
                 )
                 order by ri.position, ri.id
               )
        from public.restaurant_images ri
        where ri.restaurant_id = r.id
      ),
      '[]'::jsonb
    ) as restaurant_images,
    coalesce(
      (
        select pg_catalog.jsonb_agg(
                 pg_catalog.jsonb_build_object(
                   'id', d.id,
                   'name', d.name,
                   'description', d.description,
                   'price_rm', d.price_rm,
                   'image_url', d.image_url,
                   'position', d.position
                 )
                 order by d.position, d.id
               )
        from public.dishes d
        where d.restaurant_id = r.id
      ),
      '[]'::jsonb
    ) as dishes,
    coalesce(
      (
        select pg_catalog.jsonb_agg(
                 pg_catalog.jsonb_build_object(
                   'author_name', rv.author_name,
                   'body', rv.body
                 )
                 order by rv.created_at desc, rv.id
               )
        from public.reviews rv
        where rv.restaurant_id = r.id
      ),
      '[]'::jsonb
    ) as reviews,
    public.haversine_km(c.lat, c.lng, r.latitude, r.longitude) as distance_km,
    -- Null when the caption never said when the place opens; the client hides
    -- the line rather than guessing.
    public.is_open_at(r.opens_at, r.closes_at, r.closed_dow, pg_catalog.now())
      as open_now,
    -- Already seen on the deck, liked or passed. Never a reason to hide the
    -- pin; only a reason to leave it out of "Swipe all n" (D117).
    exists (
      select 1
      from public.swipes s
      where s.restaurant_id = r.id
        and s.user_id = (select auth.uid())
    ) as swiped
  from public.restaurants r
  cross join ctx c
  where r.is_active
    -- Nowhere to measure from is an empty map, not the whole catalogue.
    and c.lat is not null
    and c.lng is not null
    -- (0,0) is the scraper's "no coordinates", not a place in the Gulf of
    -- Guinea: an ungeocoded row has no pin to draw.
    and (r.latitude <> 0 or r.longitude <> 0)
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
    -- rows, and dropping them would empty the map for anyone who answered
    -- the budget question at all (D105).
    and (
      c.budget_max is null
      or r.price_from is null
      or r.price_from <= c.budget_max
    )
    -- Cuisine filter: any of the picked cuisines qualifies.
    and (
      pg_catalog.cardinality(c.f_cuisines) = 0
      or exists (
        select 1 from public.restaurant_cuisines rc
        where rc.restaurant_id = r.id
          and rc.cuisine_id = any (c.f_cuisines)
      )
    )
    -- Dietary filter: every picked tag must be satisfied — these are
    -- restrictions, not preferences.
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
    and (c.f_min_rating is null or r.rating >= c.f_min_rating)
  order by public.haversine_km(c.lat, c.lng, r.latitude, r.longitude), r.id
  limit greatest(1, least(coalesce(p_limit, 60), 200));
$function$;
