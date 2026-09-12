-- handle_new_user is SECURITY DEFINER and only invoked by the auth trigger;
-- API roles must never be able to call it directly (security advisor finding).
revoke execute on function public.handle_new_user() from public, anon, authenticated;
