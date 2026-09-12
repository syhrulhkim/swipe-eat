-- A pass comes back gently (D139).
--
-- Deck exhaustion resurfaces a pass older than three days, and until now it
-- came back at exactly the score it left with: a place passed on Monday and a
-- place passed in March were the same card to the ranker. Three days is also
-- the only thing that separated "not this session" from "ready to ask again".
--
-- The floor stays a hard `where` — a decayed score near zero would otherwise
-- ride the jitter back to the top of a thin deck — and above it the score
-- decays in: `score × least(1, age_days / 7)`. A four-day-old pass returns
-- quietly, a month-old one at full strength.
--
-- Only bucket 1 is touched, and bucket 0 always sorts first, so this can only
-- reorder cards that come back. On a deck that is not exhausted it changes
-- nothing at all.
--
-- A Ngap never returns: it lives in Bites, and re-showing it reads as a bug.
-- A Later never returns either, because D95 makes it a like — that is the
-- real gap, and it is §8's, not this one's.

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
      -- Once. Every bucket reads this, and `materialized` is what guarantees
      -- the ranker is not run a second time to answer the second one (D142).
      select d.restaurant_id, d.score, d.swiped_at, d.liked
      from public.deck_scored(
        p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour
      ) d
    ),
    decayed as (
      -- A pass comes back gently (D139). The three-day floor is still a hard
      -- `where` below — a place passed ten minutes ago must not reappear this
      -- session, and a decayed score near zero would otherwise win on jitter
      -- alone. Above the floor a resurfaced card returns at
      -- `score × least(1, age_days / 7)`: quiet at four days, at full strength
      -- after a week. A card nobody has swiped is untouched.
      --
      -- `greatest(score, 0)` because the open-now penalty (D138) can in
      -- principle take a signal-less row below zero, and multiplying a
      -- negative by a fraction would *raise* it.
      select
        s.restaurant_id,
        case
          when s.swiped_at is null then s.score
          else greatest(s.score, 0) * least(
            1.0::double precision,
            extract(epoch from (pg_catalog.now() - s.swiped_at))::double precision
              / 604800.0
          )
        end as score,
        s.swiped_at,
        s.liked
      from scored s
    ),
    cuisine_of as (
      -- No active restaurant carries more than one cuisine today, so this is
      -- "the" cuisine. `min` keeps it single-valued the day that changes.
      select rc.restaurant_id, min(rc.cuisine_id) as cuisine_id
      from public.restaurant_cuisines rc
      group by rc.restaurant_id
    ),
    -- Bucket 0 is a card nobody has seen. Bucket 1 is deck exhaustion: the
    -- catalogue goes fast, so rather than show an empty deck, resurface passes
    -- older than three days — the retention the device-local
    -- SeenRestaurantsStore used, measured from the last swipe (D135). Likes
    -- never come back: they live in the Bites tab, and re-showing them reads
    -- as a bug.
    served as (
      select
        s.restaurant_id,
        (case when s.swiped_at is null then 0 else 1 end) as bucket,
        -- The nth card of a cuisine loses 0.02 × (n − 1), counted over every
        -- candidate rather than over the thirty that fit, so the penalty
        -- decides which thirty those are (D137).
        s.score - 0.02 * (row_number() over (
          partition by (case when s.swiped_at is null then 0 else 1 end),
                       coalesce(c.cuisine_id, 0)
          order by s.score desc, s.restaurant_id
        ) - 1) as score
      from decayed s
      left join cuisine_of c on c.restaurant_id = s.restaurant_id
      where s.swiped_at is null
         or (
           s.liked is false
           and s.swiped_at < pg_catalog.now() - interval '3 days'
         )
    ),
    -- `bucket` first, so a card nobody has seen always beats a card coming
    -- back, and the resurfaced ones only ever fill what is left of the limit.
    picked as (
      select v.restaurant_id, v.bucket, v.score
      from served v
      order by v.bucket, v.score desc, v.restaurant_id
      limit v_limit
    )
    -- The columns are joined back *after* the limit: thirty wide rows, not
    -- the whole catalogue (D142).
    select r.*
    from picked p
    join public.restaurants r on r.id = p.restaurant_id
    order by p.bucket, p.score desc, p.restaurant_id;
end
$$;
