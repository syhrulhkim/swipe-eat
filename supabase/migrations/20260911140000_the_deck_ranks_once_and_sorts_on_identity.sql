-- The deck ranks once, sorts on identity, and lets its arithmetic inline (D142).
--
-- Four things, all measured against the live project with 1,607 active rows
-- and a 500 km radius (576 candidates): 52 ms before, 36 ms after the three
-- ALTERs alone.
--
-- 1. `get_deck` ran the whole ranker a second time whenever the first query
--    came back short. That is the exhaustion path, which is not an edge case
--    on a catalogue this size — it is the common case for anyone who swipes.
--    One `materialized` CTE now feeds both buckets.
-- 2. It sorted rows carrying `r.*` — every column of `restaurants`, the
--    `search` tsvector included — to pick thirty. It now sorts `(bucket,
--    score, id)` and joins the columns back after the limit.
-- 3. `haversine_km`, `tiktok_video_id` and `deck_jitter` each carried
--    `set search_path = ''`, and Postgres refuses to inline a SQL function
--    that has a SET clause. Three function calls per row through the executor
--    instead of folded arithmetic, over every row of the catalogue.
-- 4. `rows 300` told the planner to expect a fifth of what `deck_scored`
--    actually returns when nobody has set a radius.
--
-- On (3): this re-raises Supabase's `function_search_path_mutable` advisor
-- warning on all three, and that is accepted on the record here the way D109
-- accepted its own. All three are `security invoker` pure arithmetic — they
-- read no table, so there is no definer's privilege to escalate — and every
-- name in their bodies (`sin`, `radians`, `substring`, `hashtextextended`)
-- resolves out of `pg_catalog`, which Postgres searches first whenever the
-- path does not name it explicitly. An unprivileged role cannot shadow them.

alter function public.haversine_km(
  double precision, double precision, double precision, double precision
) reset search_path;
alter function public.tiktok_video_id(text) reset search_path;
alter function public.deck_jitter(bigint, bigint) reset search_path;

-- The estimate, not the body: 1,607 active rows is the ceiling when no radius
-- narrows them, and the planner was being told 300.
alter function public.deck_scored(
  double precision, double precision, bigint, integer, integer
) rows 1600;

create or replace function public.get_deck(
  p_limit integer default 30,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_seed bigint default null,
  p_radius_km integer default null,
  p_local_hour integer default null
)
returns setof public.restaurants
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 30), 1), 100);
begin
  return query
    with scored as materialized (
      -- Once. Both buckets read this, and `materialized` is what guarantees
      -- the ranker is not run a second time to answer the second one.
      select d.restaurant_id, d.score, d.swiped_at, d.liked
      from public.deck_scored(
        p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour
      ) d
    ),
    fresh as (
      select s.restaurant_id, s.score, 0 as bucket
      from scored s
      where s.swiped_at is null
      order by s.score desc, s.restaurant_id
      limit v_limit
    ),
    -- Deck exhaustion: the catalogue goes fast. Rather than showing an empty
    -- deck, resurface passes older than three days (the retention the
    -- device-local SeenRestaurantsStore used), measured from the last swipe
    -- (D135). Likes never come back — they live in the Bites tab, and
    -- re-showing them reads as a bug.
    resurfaced as (
      select s.restaurant_id, s.score, 1 as bucket
      from scored s
      where s.swiped_at is not null
        and s.liked is false
        and s.swiped_at < pg_catalog.now() - interval '3 days'
      order by s.score desc, s.restaurant_id
      limit v_limit
    ),
    -- `bucket` first, so a card nobody has seen always beats a card coming
    -- back, and the resurfaced ones only ever fill what is left of the limit.
    picked as (
      select f.restaurant_id, f.score, f.bucket from fresh f
      union all
      select rs.restaurant_id, rs.score, rs.bucket from resurfaced rs
      order by bucket, score desc, restaurant_id
      limit v_limit
    )
    -- The columns are joined back *after* the limit: thirty wide rows, not
    -- the whole catalogue.
    select r.*
    from picked p
    join public.restaurants r on r.id = p.restaurant_id
    order by p.bucket, p.score desc, p.restaurant_id;
end
$$;
