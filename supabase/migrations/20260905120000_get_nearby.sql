-- The Nearby map's one query: every active, geocoded restaurant inside a
-- radius of the caller's position, closest first, with the distance and the
-- open-now answer already computed.
--
-- It applies exactly the discovery filters `deck_scored` applies
-- (filter_cuisine_ids, filter_dietary_tag_ids, filter_min_rating) so the
-- Filters button means the same thing on the deck and on the map.
--
-- Images, dishes and reviews come back as jsonb in the same shape PostgREST's
-- embedding would produce, so the client feeds a row straight to
-- `Restaurant.fromJson` in one round trip — a `returns table` cannot be
-- `.select()`-embedded the way a `setof restaurants` RPC can.
--
-- Additive only: nothing here drops or alters an existing object.
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
  open_now boolean
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
      as open_now
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
  is 'Nearby map: active, geocoded restaurants within p_radius_km of the caller, closest first, with distance_km and open_now. Applies the profile''s discovery filters, the same ones deck_scored applies.';

-- Mirrors the grants on `get_top_picks`: reachable from the app's two roles,
-- not from PUBLIC.
revoke all on function public.get_nearby(double precision, double precision, double precision, int) from public;
grant execute on function public.get_nearby(double precision, double precision, double precision, int) to anon, authenticated, service_role;
