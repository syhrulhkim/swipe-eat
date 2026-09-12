-- The place name belongs to the fix, not to the profile.
--
-- `update_location` used to coalesce a missing p_place_name back to the row's
-- existing name. Reverse geocoding goes through the OS service, which is rate
-- limited and offline-fragile, so "missing" is a normal outcome — and the
-- result was a profile carrying new coordinates under the *previous* place's
-- name. The header chip then told the user they were somewhere they had left.
--
-- A name with no fix under it is worse than no name: the header falls back to
-- "Nearby", which is true.

create or replace function public.update_location(
  p_latitude double precision,
  p_longitude double precision,
  p_place_name text default null,
  p_source text default 'gps'
) returns public.profiles
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'update_location requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set last_latitude = p_latitude,
         last_longitude = p_longitude,
         last_place_name = nullif(btrim(p_place_name), ''),
         located_at = pg_catalog.now(),
         location_source = coalesce(p_source, 'gps')
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  return v_profile;
end $$;

revoke execute on function public.update_location(double precision, double precision, text, text) from public;
grant execute on function public.update_location(double precision, double precision, text, text) to authenticated, service_role;
