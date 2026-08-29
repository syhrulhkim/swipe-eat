-- One clip belongs to one restaurant.
--
-- Two rows sharing a video_url means the deck plays the same video twice under
-- two different names, and the warm-player cache — keyed by URL — hands the
-- same controller to both cards. The first seed batch left three such pairs
-- behind: an early row and the row seed.sql now defines for that clip.
--
-- The older row is the wrong one every time, so keep the highest id per clip.
-- On a database built from seed.sql this deletes nothing; the clips there are
-- already distinct.
delete from public.restaurants as stale
where stale.video_url is not null
  and stale.video_url <> ''
  and exists (
    select 1
    from public.restaurants as newer
    where newer.video_url = stale.video_url
      and newer.id > stale.id
  );

-- Partial, because a restaurant with no clip is normal and the app reads both
-- null and '' as "no clip".
create unique index if not exists restaurants_video_url_key
  on public.restaurants (video_url)
  where video_url is not null and video_url <> '';
