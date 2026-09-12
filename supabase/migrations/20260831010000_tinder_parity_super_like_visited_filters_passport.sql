-- Tinder-parity backend: super like, rewind, visited, discovery filters,
-- passport, top picks and swipe stats. See docs/tinder-parity-plan.md for the
-- reasoning; the short version of every choice:
--
--   * swipes.liked stays a boolean. Super like is a second flag, because an
--     enum would break get_deck's exhaustion branch, get_liked_restaurants
--     and the partial like index for no gain.
--   * Rewind DELETES the swipe row. record_swipe(liked => false) would leave
--     the restaurant "seen" and it would never be dealt again.
--   * Filters and passport live on profiles, like search_radius_km already
--     does, so they survive a reinstall and apply server-side where the
--     client cannot forget to pass them.

-- ============ swipes: the two new facts about a decision ============

alter table public.swipes
  add column super_like boolean not null default false,
  -- When the user actually went. Null = not visited; independent of liked so
  -- a pass the user later ate at anyway still counts.
  add column visited_at timestamptz;

create index swipes_user_super_idx on public.swipes (user_id)
  where super_like;
create index swipes_user_visited_idx on public.swipes (user_id, visited_at desc)
  where visited_at is not null;

-- 'visited' marks rows created by mark_visited for a place the user never
-- swiped: the row exists to carry visited_at, not a deck decision.
alter table public.swipes drop constraint if exists swipes_source_check;
alter table public.swipes
  add constraint swipes_source_check
  check (source in ('deck', 'explore', 'detail', 'likes', 'visited'));

-- ============ profiles: filters + passport ============

alter table public.profiles
  -- Discovery filters. Empty array = filter off; they are hard limits on the
  -- deck, unlike profile_cuisines which only weights the score.
  add column filter_cuisine_ids bigint[] not null default '{}',
  add column filter_dietary_tag_ids bigint[] not null default '{}',
  add column filter_min_rating numeric(2,1)
    check (filter_min_rating is null or filter_min_rating between 0 and 5),
  -- Passport: a manually pinned location that beats the GPS fix while set.
  -- Null = off. Resolved server-side in deck_scored so the client cannot
  -- accidentally override an active passport by passing its real fix, which
  -- it does on every deck load.
  add column passport_latitude double precision
    check (passport_latitude between -90 and 90),
  add column passport_longitude double precision
    check (passport_longitude between -180 and 180),
  add column passport_place_name text;

-- ============ deck_scored: passport + filters ============
-- Same signature, new ctx. Filters sit in the candidates CTE so both of
-- get_deck's paths (fresh cards and the exhaustion fallback) obey them.

create or replace function public.deck_scored(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_seed bigint default null,
  p_radius_km int default null,
  p_local_hour int default null
) returns table (
  restaurant_id bigint,
  score double precision,
  distance_km double precision,
  swiped_at timestamptz,
  liked boolean
)
language sql stable security invoker set search_path = '' rows 300 as $$
  with me as (
    select p.*
    from public.profiles p
    where p.id = (select auth.uid())
  ),
  ctx as (
    select
      -- passport pin beats the device fix beats the stored last location
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
      -- an explicit argument wins; otherwise the Settings value; null = no limit
      coalesce(p_radius_km, (select m.search_radius_km from me m)) as radius_km,
      coalesce((select m.morning_mode from me m), true) as morning_mode,
      coalesce((select m.spice_bias from me m), 'medium') as spice_bias,
      coalesce((select m.nearby_focus from me m), true) as nearby_focus,
      coalesce((select m.filter_cuisine_ids from me m),
               '{}'::bigint[]) as f_cuisines,
      coalesce((select m.filter_dietary_tag_ids from me m),
               '{}'::bigint[]) as f_diet,
      (select m.filter_min_rating from me m) as f_min_rating,
      coalesce(
        p_seed,
        pg_catalog.hashtext(
          coalesce((select auth.uid())::text, 'anon') || ':' ||
          (pg_catalog.now() at time zone 'Asia/Kuala_Lumpur')::date::text
        )::bigint
      ) as seed,
      coalesce(
        p_local_hour,
        pg_catalog.date_part('hour', pg_catalog.now() at time zone 'Asia/Kuala_Lumpur')::int
      ) as local_hour
  ),
  candidates as (
    select
      r.id,
      r.rating,
      r.video_url,
      s.created_at as swiped_at,
      s.liked,
      case
        when c.lat is null or c.lng is null then null
        when r.latitude = 0 and r.longitude = 0 then null
        else public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
      end as km,
      c.*
    from public.restaurants r
    cross join ctx c
    left join public.swipes s
      on s.restaurant_id = r.id and s.user_id = (select auth.uid())
    where r.is_active
      and (
        -- no radius, or nowhere to measure from: everything stays in play
        c.radius_km is null or c.lat is null or c.lng is null
        or (
          (r.latitude <> 0 or r.longitude <> 0)
          and public.haversine_km(c.lat, c.lng, r.latitude, r.longitude)
              <= c.radius_km
        )
      )
      -- cuisine filter: any of the picked cuisines qualifies
      and (
        pg_catalog.cardinality(c.f_cuisines) = 0
        or exists (
          select 1 from public.restaurant_cuisines rc
          where rc.restaurant_id = r.id
            and rc.cuisine_id = any (c.f_cuisines)
        )
      )
      -- dietary filter: every picked tag must be satisfied — these are
      -- restrictions, not preferences, so "vegetarian and halal" means both
      and (
        pg_catalog.cardinality(c.f_diet) = 0
        or not exists (
          select 1 from pg_catalog.unnest(c.f_diet) as want(tag_id)
          where not exists (
            select 1 from public.restaurant_dietary_tags rdt
            where rdt.restaurant_id = r.id
              and rdt.dietary_tag_id = want.tag_id
          )
        )
      )
      -- minimum rating. Unrated rows (rating 0) fall out too: a filter that
      -- quietly kept them would not be a filter.
      and (c.f_min_rating is null or r.rating >= c.f_min_rating)
  ),
  taste as (
    select
      rc.restaurant_id,
      max(case when pc.cuisine_id is not null then 1 else 0 end) as matches_pick,
      max(case when cu.is_breakfast then 1 else 0 end) as breakfasty,
      max(cu.spice_level) as spice_level
    from public.restaurant_cuisines rc
    join public.cuisines cu on cu.id = rc.cuisine_id and cu.is_active
    left join public.profile_cuisines pc
      on pc.cuisine_id = rc.cuisine_id
     and pc.profile_id = (select auth.uid())
    group by rc.restaurant_id
  ),
  diet as (
    select rdt.restaurant_id, 1 as matches
    from public.restaurant_dietary_tags rdt
    join public.profile_dietary_tags pdt
      on pdt.dietary_tag_id = rdt.dietary_tag_id
     and pdt.profile_id = (select auth.uid())
    group by rdt.restaurant_id
  ),
  ranked as (
    select
      cand.*,
      -- rank percentile, not raw value: immune to gaps between video ids
      percent_rank() over (
        order by coalesce(public.tiktok_video_id(cand.video_url), 0), cand.id
      ) as freshness
    from candidates cand
  )
  select
    ranked.id,
    -- proximity: 1.0 at 0 km, 0.5 at 12 km, ~0 far away. Unknown location gets
    -- neutral half credit so an ungeocoded row is not locked out of the front.
    0.30 * (case when ranked.nearby_focus then 1.5 else 1.0 end)
         * (case
              when ranked.lat is null then 0
              when ranked.km is null then 0.5
              else power(2, -ranked.km / 12.0)
            end)
    + 0.20 * ranked.freshness
    -- 283 of 288 rows are unrated: scoring them all as 0 would flatten the
    -- signal, so an unrated row hands its weight to exploration instead.
    + (case when ranked.rating > 0 then 0.15 * least(ranked.rating, 5) / 5.0
            else 0 end)
    + 0.25 * (
        0.60 * coalesce(t.matches_pick, 0)
        + (case
             when ranked.morning_mode and ranked.local_hour < 11
                  and coalesce(t.breakfasty, 0) = 1 then 0.25
             else 0
           end)
        + 0.15 * (case
                    when t.spice_level is null then 0
                    else greatest(0, 1 - abs(
                      t.spice_level - case ranked.spice_bias
                                        when 'low' then 0
                                        when 'medium' then 1
                                        else 2
                                      end
                    ) / 2.0)
                  end)
      )
    + 0.10 * coalesce(d.matches, 0)
    + (0.35 + case when ranked.rating > 0 then 0 else 0.15 end)
      * public.deck_jitter(ranked.id, ranked.seed)
    as score,
    ranked.km,
    ranked.swiped_at,
    ranked.liked
  from ranked
  left join taste t on t.restaurant_id = ranked.id
  left join diet d on d.restaurant_id = ranked.id;
$$;

-- ============ record_swipe: gains p_super_like ============
-- New parameter = new signature, so this is a drop + create, and the
-- revoke/grant pair has to be reissued: a fresh function comes with execute
-- granted to PUBLIC, which anon inherits.

drop function public.record_swipe(bigint, boolean, text, double precision, double precision);

create function public.record_swipe(
  p_restaurant_id bigint,
  p_liked boolean,
  p_source text default 'deck',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_super_like boolean default false
) returns void
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'record_swipe requires an authenticated user'
      using errcode = '42501';
  end if;

  insert into public.swipes (
    user_id, restaurant_id, liked, source,
    swiped_at_latitude, swiped_at_longitude, super_like
  )
  values (
    v_user, p_restaurant_id, p_liked, coalesce(p_source, 'deck'),
    p_latitude, p_longitude,
    -- a super like is a like; refuse the contradiction rather than storing it
    coalesce(p_super_like, false) and p_liked
  )
  on conflict (user_id, restaurant_id) do update
    set liked = excluded.liked,
        source = excluded.source,
        swiped_at_latitude = excluded.swiped_at_latitude,
        swiped_at_longitude = excluded.swiped_at_longitude,
        -- a re-swipe is a new decision; visited_at is not, so it survives
        super_like = excluded.super_like;
end $$;

-- ============ undo_swipe: rewind ============

create function public.undo_swipe(p_restaurant_id bigint) returns void
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'undo_swipe requires an authenticated user'
      using errcode = '42501';
  end if;

  delete from public.swipes s
   where s.user_id = v_user and s.restaurant_id = p_restaurant_id;
end $$;

-- ============ mark_visited ============
-- Usually updates the existing swipe row; inserting (liked = false, source
-- 'visited') covers marking a place found outside the deck.

create function public.mark_visited(
  p_restaurant_id bigint,
  p_visited boolean default true
) returns void
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'mark_visited requires an authenticated user'
      using errcode = '42501';
  end if;

  insert into public.swipes (user_id, restaurant_id, liked, source, visited_at)
  values (
    v_user, p_restaurant_id, false, 'visited',
    case when p_visited then pg_catalog.now() end
  )
  on conflict (user_id, restaurant_id) do update
    set visited_at = case when p_visited then pg_catalog.now() end;
end $$;

-- ============ set_discovery_filters ============
-- Full overwrite on every call: the sheet always writes its whole state, so
-- there is no "null means keep" ambiguity.

create function public.set_discovery_filters(
  p_cuisine_ids bigint[],
  p_dietary_tag_ids bigint[],
  p_min_rating numeric
) returns public.profiles
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'set_discovery_filters requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set filter_cuisine_ids = coalesce(p_cuisine_ids, '{}'),
         filter_dietary_tag_ids = coalesce(p_dietary_tag_ids, '{}'),
         filter_min_rating = p_min_rating
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  return v_profile;
end $$;

-- ============ set_passport ============
-- Both coordinates set = pin there; both null = back to the real location.

create function public.set_passport(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_place_name text default null
) returns public.profiles
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'set_passport requires an authenticated user'
      using errcode = '42501';
  end if;

  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'passport needs both coordinates or neither'
      using errcode = '22023';
  end if;

  update public.profiles p
     set passport_latitude = p_latitude,
         passport_longitude = p_longitude,
         passport_place_name = case
           when p_latitude is null then null
           else coalesce(nullif(btrim(p_place_name), ''), p.passport_place_name)
         end
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  return v_profile;
end $$;

-- ============ reads ============

-- Super likes surface first: "must try" outranks recency.
create or replace function public.get_liked_restaurants(
  p_limit int default 50,
  p_offset int default 0
) returns setof public.restaurants
language sql stable security invoker set search_path = '' as $$
  select r.*
  from public.swipes s
  join public.restaurants r on r.id = s.restaurant_id
  where s.user_id = (select auth.uid())
    and s.liked
    and r.is_active
  order by s.super_like desc, s.updated_at desc, s.restaurant_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- The Liked grid badges super likes, but get_liked_restaurants returns
-- setof restaurants so PostgREST can embed images and reviews — widening it
-- to carry a flag would cost the embed. A second cheap call is the smaller
-- price.
create function public.get_super_liked_ids() returns setof bigint
language sql stable security invoker set search_path = '' as $$
  select s.restaurant_id
  from public.swipes s
  where s.user_id = (select auth.uid()) and s.super_like;
$$;

create function public.get_visited_restaurants(
  p_limit int default 50,
  p_offset int default 0
) returns setof public.restaurants
language sql stable security invoker set search_path = '' as $$
  select r.*
  from public.swipes s
  join public.restaurants r on r.id = s.restaurant_id
  where s.user_id = (select auth.uid())
    and s.visited_at is not null
    and r.is_active
  order by s.visited_at desc, s.restaurant_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create function public.get_reviewed_restaurants(
  p_limit int default 50,
  p_offset int default 0
) returns setof public.restaurants
language sql stable security invoker set search_path = '' as $$
  select r.*
  from public.restaurants r
  where r.is_active
    and exists (
      select 1 from public.reviews v
      where v.restaurant_id = r.id and v.user_id = (select auth.uid())
    )
  order by (
    select max(v.created_at) from public.reviews v
    where v.restaurant_id = r.id and v.user_id = (select auth.uid())
  ) desc, r.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Top picks: the head of today's deck, no exhaustion fallback. deck_scored
-- already seeds off the date in Asia/Kuala_Lumpur, so the shortlist is stable
-- for a day and rerolls at midnight for free.
create function public.get_top_picks(
  p_limit int default 10,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns setof public.restaurants
language sql stable security invoker set search_path = '' as $$
  select r.*
  from public.restaurants r
  join public.deck_scored(p_latitude, p_longitude) d
    on d.restaurant_id = r.id
  where d.swiped_at is null
  order by d.score desc, r.id
  limit least(greatest(coalesce(p_limit, 10), 1), 20);
$$;

-- Swipes today (for the daily-limit chip) and the streak of consecutive days
-- with at least one swipe, anchored to today or, failing that, yesterday —
-- a streak should not read 0 at breakfast because the user slept.
create function public.get_swipe_stats()
returns table (swipes_today int, streak_days int)
language plpgsql stable security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_today date := (pg_catalog.now() at time zone 'Asia/Kuala_Lumpur')::date;
  v_anchor date;
  v_swipes_today int;
  v_streak int;
begin
  if v_user is null then
    raise exception 'get_swipe_stats requires an authenticated user'
      using errcode = '42501';
  end if;

  select count(*) into v_swipes_today
  from public.swipes s
  where s.user_id = v_user
    and (s.created_at at time zone 'Asia/Kuala_Lumpur')::date = v_today;

  select max((s.created_at at time zone 'Asia/Kuala_Lumpur')::date)
    into v_anchor
  from public.swipes s
  where s.user_id = v_user;

  if v_anchor is null or v_anchor < v_today - 1 then
    v_streak := 0;
  else
    -- Walk distinct swipe days newest-first; the streak is the prefix where
    -- each day is exactly one before the last. Once a gap appears the dates
    -- fall permanently behind the expected sequence, so a plain count works.
    select count(*) into v_streak
    from (
      select d,
             v_anchor - (row_number() over (order by d desc) - 1)::int
               as expected
      from (
        select distinct (s.created_at at time zone 'Asia/Kuala_Lumpur')::date as d
        from public.swipes s
        where s.user_id = v_user
      ) days
      where d <= v_anchor
    ) run
    where run.d = run.expected;
  end if;

  return query select v_swipes_today, v_streak;
end $$;

-- Explore's category grid: every active cuisine with how many places serve
-- it and a cover photo from its best-rated restaurant. Catalog data, so it
-- keeps the default (public) execute like the other catalog reads.
create function public.get_cuisine_counts()
returns table (
  cuisine_id bigint,
  slug text,
  label text,
  emoji text,
  restaurant_count bigint,
  cover_url text
)
language sql stable security invoker set search_path = '' as $$
  select
    c.id,
    c.slug,
    c.label,
    c.emoji,
    count(distinct rc.restaurant_id),
    (
      select ri.url
      from public.restaurant_images ri
      join public.restaurant_cuisines rc2 on rc2.restaurant_id = ri.restaurant_id
      join public.restaurants r2 on r2.id = ri.restaurant_id and r2.is_active
      where rc2.cuisine_id = c.id
      order by r2.rating desc, ri.position, ri.id
      limit 1
    )
  from public.cuisines c
  join public.restaurant_cuisines rc on rc.cuisine_id = c.id
  join public.restaurants r on r.id = rc.restaurant_id and r.is_active
  where c.is_active
  group by c.id, c.slug, c.label, c.emoji
  order by count(distinct rc.restaurant_id) desc, c.position;
$$;

-- Explore obeys the passport too: while pinned elsewhere, "what the user
-- cannot be served, they cannot find" has to hold from the pinned city.
create or replace function public.search_restaurants(
  p_query text default null,
  p_limit int default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km int default null
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

-- ============ grants ============
-- User-scoped reads and writes: revoke the PUBLIC execute a fresh function is
-- born with (anon inherits it), then grant the two roles that belong here.

revoke execute on function public.record_swipe(bigint, boolean, text, double precision, double precision, boolean) from public;
revoke execute on function public.undo_swipe(bigint) from public;
revoke execute on function public.mark_visited(bigint, boolean) from public;
revoke execute on function public.set_discovery_filters(bigint[], bigint[], numeric) from public;
revoke execute on function public.set_passport(double precision, double precision, text) from public;
revoke execute on function public.get_super_liked_ids() from public;
revoke execute on function public.get_visited_restaurants(int, int) from public;
revoke execute on function public.get_reviewed_restaurants(int, int) from public;
revoke execute on function public.get_top_picks(int, double precision, double precision) from public;
revoke execute on function public.get_swipe_stats() from public;

grant execute on function public.record_swipe(bigint, boolean, text, double precision, double precision, boolean) to authenticated, service_role;
grant execute on function public.undo_swipe(bigint) to authenticated, service_role;
grant execute on function public.mark_visited(bigint, boolean) to authenticated, service_role;
grant execute on function public.set_discovery_filters(bigint[], bigint[], numeric) to authenticated, service_role;
grant execute on function public.set_passport(double precision, double precision, text) to authenticated, service_role;
grant execute on function public.get_super_liked_ids() to authenticated, service_role;
grant execute on function public.get_visited_restaurants(int, int) to authenticated, service_role;
grant execute on function public.get_reviewed_restaurants(int, int) to authenticated, service_role;
grant execute on function public.get_top_picks(int, double precision, double precision) to authenticated, service_role;
grant execute on function public.get_swipe_stats() to authenticated, service_role;
