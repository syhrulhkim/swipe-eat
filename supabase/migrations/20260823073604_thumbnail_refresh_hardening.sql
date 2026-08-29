-- Review hardening for the thumbnail cache pipeline.
--
-- 1) expires_at described the *temporary TikTok source URL*, not the row's
--    url (which points at permanent Storage and never expires). Rename it so
--    no future sweep treats cached rows as expiring.
alter table public.restaurant_images
  rename column expires_at to source_expires_at;

comment on column public.restaurant_images.source_expires_at is
  'Expiry of the temporary TikTok CDN source_url only. url points at a '
  'permanent Storage object and is never governed by this column.';

-- 2) Failures were terminal: nothing retried metadata_status = ''failed''.
--    Track attempts so the refresh job can retry failed rows (the 6-hourly
--    cron spacing acts as backoff) and give up after a cap instead of never.
alter table public.restaurant_images
  add column if not exists refresh_attempts integer not null default 0;

create index if not exists restaurant_images_refresh_queue_idx
  on public.restaurant_images (metadata_status, refresh_attempts);

-- Atomic failure bookkeeping for the edge function (PostgREST updates cannot
-- express refresh_attempts = refresh_attempts + 1). Security invoker: the
-- service-role caller already holds the table privileges.
create or replace function public.record_thumbnail_refresh_failure(image_id bigint)
returns void
language sql
set search_path = ''
as $$
  update public.restaurant_images
  set metadata_status = 'failed',
      refresh_attempts = refresh_attempts + 1,
      last_synced_at = now()
  where id = image_id;
$$;

revoke execute on function public.record_thumbnail_refresh_failure(bigint)
  from public, anon, authenticated;
grant execute on function public.record_thumbnail_refresh_failure(bigint)
  to service_role;

-- 3) Defense in depth on the bucket: the edge function already rejects
--    non-image content types before uploading; enforce the same at Storage.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'image/heic', 'image/heif'
    ]
where id = 'restaurant-images';
