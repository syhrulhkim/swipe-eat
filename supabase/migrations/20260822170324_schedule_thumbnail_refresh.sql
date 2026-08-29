-- plan.md "Refresh Scheduling": a scheduled backend process dispatches the
-- metadata refresh job in small batches. With thumbnails cached in Storage
-- this normally finds nothing to do; it exists to pick up newly scraped
-- restaurants (status 'pending') and rows manually marked 'stale'.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'refresh-tiktok-thumbnails',
  '15 */6 * * *',
  $$
  select net.http_post(
    url := 'https://vpcldlhqpvunnuexecgn.supabase.co/functions/v1/refresh-thumbnails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-refresh-key', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'thumbnail_refresh_key'
      )
    ),
    body := '{"batch": 25}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
