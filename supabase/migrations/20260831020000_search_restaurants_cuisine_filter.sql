-- Explore's category grid opens a per-cuisine list, and that list must obey
-- the same rules as every other browse surface: radius, passport, is_active.
-- Rather than a second list function that would drift from this one, the
-- cuisine filter becomes one more optional parameter on search_restaurants.
--
-- Postgres treats a new default parameter as a new overload, and PostgREST
-- refuses ambiguous RPC names — so the old signature is dropped, not shadowed.

drop function if exists public.search_restaurants(
  text, int, double precision, double precision, int
);

create function public.search_restaurants(
  p_query text default null,
  p_limit int default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km int default null,
  p_cuisine_id bigint default null
) returns setof public.restaurants
language sql stable security invoker set search_path = '' as $$
  with me as (
    select p.* from public.profiles p where p.id = (select auth.uid())
  ),
  ctx as (
    select
      coalesce(
        (select m.passport_latitude from me m),
        p_latitude,
        (select m.last_latitude from me m)
      ) as lat,
      coalesce(
        (select m.passport_longitude from me m),
        p_longitude,
        (select m.last_longitude from me m)
      ) as lng,
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
$$;
