-- plan.md "Thumbnail Expiration": TikTok CDN thumbnail URLs are temporary
-- cache data, never canonical identity (that is restaurants.video_url).
-- Cached copies live in the public restaurant-images bucket; these columns
-- track the temporary source URL, its expiry, and the sync lifecycle.

insert into storage.buckets (id, name, public)
values ('restaurant-images', 'restaurant-images', true)
on conflict (id) do nothing;

alter table public.restaurant_images
  add column if not exists source_url text,
  add column if not exists expires_at timestamptz,
  add column if not exists metadata_status text not null default 'pending'
    check (metadata_status in ('pending', 'cached', 'failed', 'stale')),
  add column if not exists last_synced_at timestamptz;

-- Existing rows hold raw TikTok CDN URLs: keep them as the temporary source
-- and record their signed expiry so the refresh job can prioritise.
update public.restaurant_images
set source_url = url,
    expires_at = case
      when url like '%x-expires=%'
        then to_timestamp((regexp_match(url, 'x-expires=(\d+)'))[1]::bigint)
    end
where source_url is null;
