-- Replace the thumbnail refresh cron job with an environment-portable one.
--
-- The previous job hardcoded the production functions URL, so any other
-- environment applying migrations (local reset, staging, branch) would POST
-- at production. Both the target URL and the auth key now come from this
-- environment's vault at run time; if either is missing the job logs a
-- warning and does nothing, instead of sending a garbage-header request.
--
-- Bootstrap per environment (see supabase/README.md):
--   select vault.create_secret('<random hex>', 'thumbnail_refresh_key');
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/refresh-thumbnails',
--     'thumbnail_refresh_url');
do $$
begin
  if exists (select 1 from cron.job where jobname = 'refresh-tiktok-thumbnails') then
    perform cron.unschedule('refresh-tiktok-thumbnails');
  end if;
end
$$;

select cron.schedule(
  'refresh-tiktok-thumbnails',
  '15 */6 * * *',
  $cron$
  do $job$
  declare
    refresh_key text;
    target_url text;
  begin
    select decrypted_secret into refresh_key
    from vault.decrypted_secrets where name = 'thumbnail_refresh_key';
    select decrypted_secret into target_url
    from vault.decrypted_secrets where name = 'thumbnail_refresh_url';

    if refresh_key is null or target_url is null then
      raise warning 'thumbnail refresh skipped: vault secrets thumbnail_refresh_key and/or thumbnail_refresh_url are not set in this environment';
      return;
    end if;

    perform net.http_post(
      url := target_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-refresh-key', refresh_key
      ),
      body := '{"batch": 25}'::jsonb,
      timeout_milliseconds := 120000
    );
  end
  $job$;
  $cron$
);
