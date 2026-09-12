-- Backend v2, phase 2: the deck algorithm moves from the phone into the
-- database, and every write the app makes gets a function to make it through.
--
-- Until now lib/features/restaurants/domain/deck_ranker.dart downloaded the
-- whole catalog and sorted it locally, "recently seen" lived in device
-- storage, and the user's search radius was not enforced anywhere. The Dart
-- ranker stays in the repo as the documented reference for these weights.
--
-- Deliberate differences from the Dart version:
--   * freshness sorts rows without a parseable TikTok video id oldest, rather
--     than switching the whole deck to row-id order,
--   * "recently seen" is no longer a penalty — a swipe is a fact in the
--     database, so swiped rows are excluded and only resurface through the
--     exhaustion fallback below,
--   * taste (cuisine picks, morning mode, spice bias) and the dietary boost
--     are new signals the client never had,
--   * search_radius_km is a HARD filter: a place outside it is not served at
--     all. Rows with no coordinates (85 of 288) cannot be proven inside a
--     radius, so they drop out while a radius is set and come back when the
--     user picks "No limit".

-- ============ helpers ============

-- Great-circle distance. `least(1.0, ...)` mirrors the clamp in the Dart
-- ranker: floating point can nudge the term past 1 for near-antipodal points,
-- and asin() of that is NaN, which would float the row to the deck front.
create function public.haversine_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
) returns double precision
language sql immutable parallel safe set search_path = '' as $$
  select 2 * 6371.0 * asin(sqrt(least(1.0,
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)
  )));
$$;

-- TikTok video urls end in the numeric video id, which is snowflake-like:
-- a higher id means posted later.
create function public.tiktok_video_id(video_url text)
returns bigint
language sql immutable parallel safe set search_path = '' as $$
  select substring(btrim(coalesce(video_url, '')) from '(\d{6,})\s*$')::bigint;
$$;

-- Deterministic stand-in for random(): the same (id, seed) always yields the
-- same number, so paging the deck inside one session cannot reshuffle it,
-- while a new seed rotates the whole order. The double modulo keeps the value
-- non-negative without abs(), which overflows on the minimum bigint.
create function public.deck_jitter(p_id bigint, p_seed bigint)
returns double precision
language sql immutable parallel safe set search_path = '' as $$
  select ((pg_catalog.hashtextextended(p_id::text || ':' || p_seed::text, 0)
           % 1000000) + 1000000) % 1000000 / 1000000.0;
$$;

-- ============ scoring ============
-- One place where a restaurant's deck score is defined. get_deck() calls it
-- twice (fresh cards, then the exhaustion fallback) so the two paths can never
-- drift apart.
create function public.deck_scored(
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
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng,
      -- an explicit argument wins; otherwise the Settings value; null = no limit
      coalesce(p_radius_km, (select m.search_radius_km from me m)) as radius_km,
      coalesce((select m.morning_mode from me m), true) as morning_mode,
      coalesce((select m.spice_bias from me m), 'medium') as spice_bias,
      coalesce((select m.nearby_focus from me m), true) as nearby_focus,
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

-- ============ the deck ============
-- Returns `setof public.restaurants` so PostgREST can still embed
-- restaurant_images and reviews on the result, exactly as the plain table
-- select did.
create function public.get_deck(
  p_limit int default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_seed bigint default null,
  p_radius_km int default null,
  p_local_hour int default null
) returns setof public.restaurants
language plpgsql stable security invoker set search_path = '' as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_found int;
begin
  return query
    select r.*
    from public.restaurants r
    join public.deck_scored(p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour) d
      on d.restaurant_id = r.id
    where d.swiped_at is null
    order by d.score desc, r.id
    limit v_limit;

  get diagnostics v_found = row_count;

  -- Deck exhaustion: 288 rows go fast. Rather than showing an empty deck,
  -- resurface passes older than three days (the retention the device-local
  -- SeenRestaurantsStore used). Likes never come back — they live in the Like
  -- tab, and re-showing them reads as a bug.
  if v_found < v_limit then
    return query
      select r.*
      from public.restaurants r
      join public.deck_scored(p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour) d
        on d.restaurant_id = r.id
      where d.swiped_at is not null
        and d.liked is false
        and d.swiped_at < pg_catalog.now() - interval '3 days'
      order by d.score desc, r.id
      limit v_limit - v_found;
  end if;
end $$;

-- ============ writes ============

create function public.record_swipe(
  p_restaurant_id bigint,
  p_liked boolean,
  p_source text default 'deck',
  p_latitude double precision default null,
  p_longitude double precision default null
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
    swiped_at_latitude, swiped_at_longitude
  )
  values (
    v_user, p_restaurant_id, p_liked, coalesce(p_source, 'deck'),
    p_latitude, p_longitude
  )
  on conflict (user_id, restaurant_id) do update
    set liked = excluded.liked,
        source = excluded.source,
        swiped_at_latitude = excluded.swiped_at_latitude,
        swiped_at_longitude = excluded.swiped_at_longitude;
end $$;

-- Newest like first. updated_at (not created_at) so re-liking a place moves it
-- back to the top, the way the device-local store did.
create function public.get_liked_restaurants(
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
  order by s.updated_at desc, s.restaurant_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Explore search. Honours the same radius rule as the deck: what the user
-- cannot be served, they cannot find.
create function public.search_restaurants(
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
      coalesce(p_latitude, (select m.last_latitude from me m)) as lat,
      coalesce(p_longitude, (select m.last_longitude from me m)) as lng,
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

-- One transactional write for the whole onboarding wizard: a half-finished
-- wizard leaves onboarded_at null and simply runs again next launch.
create function public.complete_onboarding(
  p_name text default null,
  p_cuisine_ids bigint[] default null,
  p_dietary_ids bigint[] default null,
  p_morning_mode boolean default null,
  p_spice_bias text default null,
  p_nearby_focus boolean default null,
  p_radius_km int default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_place_name text default null,
  p_location_source text default null
) returns public.profiles
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'complete_onboarding requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set name = coalesce(nullif(btrim(p_name), ''), p.name),
         morning_mode = coalesce(p_morning_mode, p.morning_mode),
         spice_bias = coalesce(p_spice_bias, p.spice_bias),
         nearby_focus = coalesce(p_nearby_focus, p.nearby_focus),
         -- radius is nullable on purpose ("No limit"), so an explicit null
         -- from the wizard must be able to clear it
         search_radius_km = p_radius_km,
         last_latitude = coalesce(p_latitude, p.last_latitude),
         last_longitude = coalesce(p_longitude, p.last_longitude),
         last_place_name = coalesce(p_place_name, p.last_place_name),
         located_at = case
           when p_latitude is not null and p_longitude is not null
           then pg_catalog.now() else p.located_at end,
         location_source = coalesce(p_location_source, p.location_source),
         onboarded_at = coalesce(p.onboarded_at, pg_catalog.now())
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  if p_cuisine_ids is not null then
    delete from public.profile_cuisines pc
     where pc.profile_id = v_user
       and pc.cuisine_id <> all (p_cuisine_ids);

    insert into public.profile_cuisines (profile_id, cuisine_id)
    select v_user, unnest(p_cuisine_ids)
    on conflict (profile_id, cuisine_id) do nothing;
  end if;

  if p_dietary_ids is not null then
    delete from public.profile_dietary_tags pdt
     where pdt.profile_id = v_user
       and pdt.dietary_tag_id <> all (p_dietary_ids);

    insert into public.profile_dietary_tags (profile_id, dietary_tag_id)
    select v_user, unnest(p_dietary_ids)
    on conflict (profile_id, dietary_tag_id) do nothing;
  end if;

  return v_profile;
end $$;

-- Settings / Profile edits. Every argument is optional; null leaves the value
-- alone. p_clear_radius exists because null already means "no limit" for the
-- radius itself, so it needs its own flag to be distinguishable.
create function public.update_preferences(
  p_name text default null,
  p_morning_mode boolean default null,
  p_spice_bias text default null,
  p_nearby_focus boolean default null,
  p_radius_km int default null,
  p_clear_radius boolean default false,
  p_cuisine_ids bigint[] default null,
  p_dietary_ids bigint[] default null
) returns public.profiles
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'update_preferences requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set name = coalesce(nullif(btrim(p_name), ''), p.name),
         morning_mode = coalesce(p_morning_mode, p.morning_mode),
         spice_bias = coalesce(p_spice_bias, p.spice_bias),
         nearby_focus = coalesce(p_nearby_focus, p.nearby_focus),
         search_radius_km = case
           when coalesce(p_clear_radius, false) then null
           else coalesce(p_radius_km, p.search_radius_km)
         end
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  if p_cuisine_ids is not null then
    delete from public.profile_cuisines pc
     where pc.profile_id = v_user
       and pc.cuisine_id <> all (p_cuisine_ids);

    insert into public.profile_cuisines (profile_id, cuisine_id)
    select v_user, unnest(p_cuisine_ids)
    on conflict (profile_id, cuisine_id) do nothing;
  end if;

  if p_dietary_ids is not null then
    delete from public.profile_dietary_tags pdt
     where pdt.profile_id = v_user
       and pdt.dietary_tag_id <> all (p_dietary_ids);

    insert into public.profile_dietary_tags (profile_id, dietary_tag_id)
    select v_user, unnest(p_dietary_ids)
    on conflict (profile_id, dietary_tag_id) do nothing;
  end if;

  return v_profile;
end $$;

-- The device resolves the fix and the place label; the backend keeps them so
-- every surface (deck, explore, header chip) agrees on one location.
create function public.update_location(
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
         last_place_name = coalesce(nullif(btrim(p_place_name), ''), p.last_place_name),
         located_at = pg_catalog.now(),
         location_source = coalesce(p_source, 'gps')
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  return v_profile;
end $$;

create function public.submit_quiz_answer(
  p_question_id bigint,
  p_option_id bigint
) returns public.quiz_options
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_option public.quiz_options;
begin
  if v_user is null then
    raise exception 'submit_quiz_answer requires an authenticated user'
      using errcode = '42501';
  end if;

  select o.* into v_option
  from public.quiz_options o
  where o.id = p_option_id and o.question_id = p_question_id;

  if not found then
    raise exception 'option % does not belong to question %',
      p_option_id, p_question_id using errcode = '23503';
  end if;

  insert into public.quiz_responses (user_id, question_id, option_id)
  values (v_user, p_question_id, p_option_id)
  on conflict (user_id, question_id) do update
    set option_id = excluded.option_id,
        created_at = pg_catalog.now();

  return v_option;
end $$;

-- These read or write only the caller's own rows through RLS; anon may browse
-- the catalog but has nothing here. Functions are created with execute granted
-- to PUBLIC, which anon inherits, so the revoke has to name PUBLIC — revoking
-- from anon alone would leave the PUBLIC grant standing.
revoke execute on function public.record_swipe(bigint, boolean, text, double precision, double precision) from public;
revoke execute on function public.complete_onboarding(text, bigint[], bigint[], boolean, text, boolean, int, double precision, double precision, text, text) from public;
revoke execute on function public.update_preferences(text, boolean, text, boolean, int, boolean, bigint[], bigint[]) from public;
revoke execute on function public.update_location(double precision, double precision, text, text) from public;
revoke execute on function public.submit_quiz_answer(bigint, bigint) from public;
revoke execute on function public.get_liked_restaurants(int, int) from public;

grant execute on function public.record_swipe(bigint, boolean, text, double precision, double precision) to authenticated, service_role;
grant execute on function public.complete_onboarding(text, bigint[], bigint[], boolean, text, boolean, int, double precision, double precision, text, text) to authenticated, service_role;
grant execute on function public.update_preferences(text, boolean, text, boolean, int, boolean, bigint[], bigint[]) to authenticated, service_role;
grant execute on function public.update_location(double precision, double precision, text, text) to authenticated, service_role;
grant execute on function public.submit_quiz_answer(bigint, bigint) to authenticated, service_role;
grant execute on function public.get_liked_restaurants(int, int) to authenticated, service_role;
