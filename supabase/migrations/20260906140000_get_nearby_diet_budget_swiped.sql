-- `get_nearby` gains the three hard rules the profile's diet & budget answers
-- imply (D105), and a `swiped` column so the map can tell the deck which pins
-- it would only be re-dealing (D117).
--
-- The three predicates are copied verbatim from `deck_scored`
-- (`20260905130100_deck_scored_diet_budget_filters.sql`), because a place the
-- user cannot eat at is a wrong result on the map for exactly the reason it is
-- a wrong card on the deck:
--
--   halal_only   `r.is_halal is true` — an *unknown* certification is not good
--                enough for a rule the user set to avoid eating somewhere they
--                cannot.
--   vegetarian   matched on `dietary_tags.slug = 'vegetarian'` rather than on
--                a seeded id, so the predicate survives a reseed.
--   budget_max   an unknown `price_from` passes; most rows have no price, and
--                dropping them would empty the map for anyone who answered the
--                budget question at all.
--
-- `swiped` is `exists` against the caller's own `swipes` rows. The map still
-- draws everything — a swiped place is still a place that is there — but
-- "Swipe all n" only hands over the ones the deck has never shown (D117).
--
-- The origin is deliberately *not* the passport pin, unlike `deck_scored`: the
-- client draws the me-dot and fits the camera to the origin it resolved, so the
-- RPC's p_latitude/p_longitude stay authoritative. `NearbyController` prefers
-- the passport pin before it calls, so all three agree.
--
-- Not additive: the return type grows a column, so the old function is dropped
-- first. The argument list is unchanged, so every caller is untouched.
drop function public.get_nearby(double precision, double precision, double precision, int);

create function public.get_nearby(
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
    and public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
        <= c.radius_km
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

comment on function public.get_nearby(double precision, double precision, double precision, int)
  is 'Nearby map: active, geocoded restaurants within p_radius_km of the caller, closest first, with distance_km, open_now and swiped. Applies the profile''s discovery filters and the halal/vegetarian/budget hard rules, the same ones deck_scored applies (D105). swiped says the caller already swiped that restaurant; the map still draws it, but "Swipe all" skips it (D117).';

-- Reachable from the app's signed-in roles, not from PUBLIC. `swiped` needs
-- `auth.uid()`, so there is nothing here for an anonymous caller.
revoke all on function public.get_nearby(double precision, double precision, double precision, int) from public;
grant execute on function public.get_nearby(double precision, double precision, double precision, int) to authenticated, service_role;
