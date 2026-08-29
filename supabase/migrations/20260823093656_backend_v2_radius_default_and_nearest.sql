-- The catalog is not evenly spread: of 283 active restaurants, 85 have no
-- coordinates at all and the geocoded ones cluster 68-119 km from Batu Pahat
-- (only one active row sits within 10 km of it). A 15 km default radius would
-- therefore hand a new user a near-empty deck before they ever opened
-- Settings, so the shipped default is "no limit" and the radius only ever
-- narrows things once the user asks for it.
alter table public.profiles alter column search_radius_km set default null;

-- Lets the empty state say something useful ("nearest is 17 km away") and
-- offer a radius that would actually return places, instead of a dead end.
create function public.nearest_restaurant_km(
  p_latitude double precision default null,
  p_longitude double precision default null
) returns double precision
language sql stable security invoker set search_path = '' as $$
  with me as (
    select p.* from public.profiles p where p.id = (select auth.uid())
  ),
  ctx as (
    select
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng
  )
  select min(public.haversine_km(c.lat, c.lng, r.latitude, r.longitude))
  from public.restaurants r
  cross join ctx c
  where r.is_active
    and c.lat is not null
    and c.lng is not null
    and (r.latitude <> 0 or r.longitude <> 0)
    and not exists (
      select 1 from public.swipes s
      where s.restaurant_id = r.id and s.user_id = (select auth.uid())
    );
$$;
