# Tinder feature parity, mapped onto restaurants

Tinder is a two-sided market: two people swipe, and a match is the moment both
say yes. A restaurant never swipes back. Every feature below is therefore an
*adaptation*, not a port — and four Tinder features are deliberately absent
because faking the other side of them would be a lie:

| Tinder | Why it is not here |
| --- | --- |
| Chat | Nobody on the other side to message. |
| Likes You / Boost | Requires the restaurant to swipe. |
| Subscription tiers | Monetisation scaffolding with no user value yet. |
| Mutual match | The "match" here is one-sided by definition; see the match moment below. |

## Scope agreed with the user

Build: Rewind, Super Like, the match moment, Top Picks, discovery filters,
daily swipe limit + streak, Passport, and a Matches-shaped Likes surface.

## Data model

The whole feature set needs one migration. Everything is additive; nothing that
already works changes shape.

### `swipes`

```sql
alter table public.swipes
  add column super_like boolean not null default false,
  add column visited_at timestamptz;

create index swipes_user_super_idx on public.swipes (user_id) where super_like;
```

`swipes.liked` stays a `boolean`. Converting it to an enum would break
`get_deck`'s exhaustion branch (`d.liked is false`), `get_liked_restaurants`'s
`and s.liked`, and the `swipes_user_liked_idx` partial index — three call sites
for no gain, when a second flag says the same thing.

### `profiles`

```sql
alter table public.profiles
  -- Discovery filters, persisted the way search_radius_km already is, so they
  -- survive a reinstall instead of living in device storage.
  add column filter_cuisine_ids bigint[] not null default '{}',
  add column filter_dietary_tag_ids bigint[] not null default '{}',
  add column filter_min_rating numeric(2,1)
    check (filter_min_rating is null or filter_min_rating between 0 and 5),
  -- Passport. Null = off, i.e. use the real location.
  add column passport_latitude double precision
    check (passport_latitude between -90 and 90),
  add column passport_longitude double precision
    check (passport_longitude between -180 and 180),
  add column passport_place_name text;
```

Price and opening-hours filters are **not** buildable: `restaurants` has no
price band and no hours. Filters are cuisine, dietary tag, minimum rating, and
the radius that already exists.

## Functions

### `undo_swipe(p_restaurant_id bigint) returns void`

Rewind has to **delete** the row, not write `liked = false`.
`LikesController.unlike` currently calls `record_swipe(liked: false)`, which
leaves the row in place — and `get_deck` excludes every restaurant that has a
swipe row, so an "undone" card would never be dealt again. That is correct for
unlike (the user has seen it and said no) and wrong for rewind (the user is
saying the swipe never happened).

```sql
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
```

**Client-side race.** `DeckController.recordSwipe` is optimistic: the card flies
out and the write follows. An undo firing before that write lands would delete
nothing and then the like would insert — leaving the row behind. The controller
must hold the in-flight future per restaurant and await it before deleting.

### `record_swipe` — gains `p_super_like`

Adding a parameter changes the signature, so this is a `drop` + `create`, not a
`create or replace` — otherwise Postgres keeps both and the call is ambiguous.
The `revoke ... from public` / `grant ... to authenticated, service_role` pair
must be reissued against the new signature; a fresh function is created with
`execute` granted to `PUBLIC`, which `anon` inherits.

### `get_deck` — gains the filter parameters

Also a drop + recreate + re-grant. Filters apply to both the fresh-cards query
and the exhaustion fallback, so they belong in `deck_scored`'s `candidates`
CTE rather than being bolted onto one branch of `get_deck`.

### `deck_scored` — Passport wins over GPS

```sql
coalesce(
  (select m.passport_latitude from me m),  -- manual pin beats everything
  p_latitude,                              -- the device's real fix
  (select m.last_latitude from me m)       -- last known
) as lat
```

Resolving this server-side rather than in `DeckController` means the client
cannot accidentally override an active Passport by passing a GPS fix, which it
does on every `load()`.

### `get_liked_restaurants` — super likes first

Same signature, so `create or replace`. `order by s.super_like desc,
s.updated_at desc`.

### New read RPCs

- `get_super_liked_ids() returns setof bigint` — the Likes grid needs to badge
  super likes, but `get_liked_restaurants` returns `setof public.restaurants`
  so PostgREST can embed images and reviews. Widening the return type to carry
  a flag would cost that embed. A second cheap call is the smaller price.
- `get_top_picks(p_limit int default 10, ...) returns setof public.restaurants`
  — `get_deck`'s first query with a small limit and no exhaustion fallback.
  `deck_scored` already seeds off the current date in Asia/Kuala_Lumpur, so the
  shortlist is stable for a day and rerolls at midnight for free.
- `get_swipe_stats() returns table (swipes_today int, streak_days int)` — for
  the daily limit and the streak.

## Notes carried forward

- Every new function needs its `revoke execute ... from public` and
  `grant execute ... to authenticated, service_role`, matching the pattern at
  the bottom of `20260823093541_backend_v2_deck_rpcs.sql`.
- The migration goes in `supabase/migrations/` **and** through
  `apply_migration`; doing only one desyncs the repo from the remote.
- `FakeSwipeRepository` and `FakeRestaurantRepository` in
  `test/features/restaurants/fake_restaurant_repositories.dart` implement the
  real repository interfaces, so every signature change here lands there too.
