-- Service-role-only accessor for the refresh-thumbnails shared secret: the
-- vault schema is not exposed via the Data API, so the edge function reads
-- the secret through this RPC instead. SECURITY DEFINER is required to reach
-- vault; execution is revoked from every role except service_role, so it is
-- not callable through the public API.
create or replace function public.get_thumbnail_refresh_key()
returns text
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = 'thumbnail_refresh_key';
$$;

revoke execute on function public.get_thumbnail_refresh_key() from public;
revoke execute on function public.get_thumbnail_refresh_key() from anon;
revoke execute on function public.get_thumbnail_refresh_key() from authenticated;
grant execute on function public.get_thumbnail_refresh_key() to service_role;
