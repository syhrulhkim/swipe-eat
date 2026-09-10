Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [General/PLAN.md](../General/PLAN.md), [General/RUNBOOK.md](../General/RUNBOOK.md), [Swipe-Deck.md](Swipe-Deck.md), [Profile-Preferences.md](Profile-Preferences.md), [History/backend-plan.md](../History/backend-plan.md)

# Backend Schema (as built)

> **Client drift, 2026-09-05.** The client no longer uses `undo_swipe`,
> `get_swipe_stats`, `get_super_liked_ids`, `get_visited_restaurants`,
> `get_reviewed_restaurants` or `swipes.super_like` — "save for later" moved to
> `wishlist_items` (D84, D94, D96). Nothing there has been dropped: dropping
> destroys data and is irreversible, so it wants its own decision rather than
> riding along with a client change. This document still describes the
> database as it is.

> **Changed 2026-09-10 (D121).** `set_passport` **is** dropped, and
> `deck_scored` / `search_restaurants` no longer read
> `profiles.passport_latitude/longitude`. Unused was not the whole story
> there: the columns still outranked the caller's own fix inside both
> functions, so a pin left behind before D84 kept steering a live account's
> deck. The columns remain — no data is destroyed — but nothing reads them.
> `update_location` also stopped coalescing a missing `p_place_name` back to
> the row's existing name: the name belongs to the fix.

The **as-built** state of the Supabase project `vpcldlhqpvunnuexecgn`, read from
the live database on 2026-09-03. Where this disagrees with
[History/backend-plan.md](../History/backend-plan.md), this doc is right — that
one is the original plan and the schema has grown well past it.

15 tables, 28 functions, 16 RLS policies, 3 edge functions, 1 cron job.

## 1. Conventions

Applied consistently across every migration, from the Postgres best-practices
skill:

- `bigint generated always as identity` primary keys for catalogue tables;
  `uuid` referencing `auth.users (id)` for `profiles`.
- `text` over `varchar`; `timestamptz` over `timestamp`.
- RLS enabled on **every** table, with `(select auth.uid())` rather than bare
  `auth.uid()` so Postgres caches the result per statement instead of
  evaluating it per row.
- Every policy names its roles with a `to` clause.
- An index on every foreign key and every RLS-filtered column.
- `security definer` functions always pin `set search_path = ''`.

## 2. Table map

| Table | Rows (2026-09-03) | What it is |
|---|---|---|
| `restaurants` | 1,607 | The catalogue. 1,605 active, 1,606 with video, 1,133 with coordinates |
| `restaurant_images` | 287 | Ordered gallery; also the thumbnail cache state machine |
| `reviews` | 6 | Carousel snippets. `user_id` is a hook; no write path exists |
| `cuisines` | 23 | Cuisine taxonomy, with `is_breakfast` and `spice_level` for ranking |
| `cuisine_aliases` | — | Free-text alias → cuisine, so the scraper can map captions |
| `restaurant_cuisines` | 1,607 | Join. `source` records whether a tag or a human put it there |
| `dietary_tags` | 6 | Halal, vegetarian, and friends |
| `restaurant_dietary_tags` | — | Join |
| `profiles` | 1 | 1:1 with `auth.users`. Preferences, location, filters, Passport |
| `profile_cuisines` | — | The onboarding taste signal |
| `profile_dietary_tags` | — | Dietary needs from onboarding |
| `swipes` | 33 | Every deck decision. Also the Liked list and the visit stamp |
| `wishlist_items` | 3 | Places to try. The store behind Later (D94) |
| `plans` | — | One owner, one restaurant, one date (D107). The Calendar tab |
| `plan_members` | — | Who else is on a plan. No write path until Friends |
| `plan_time_votes` | — | A member's vote on the time. No write path until Friends |
| `quiz_questions` | 1 | **Orphaned** — see [Quiz.md](Quiz.md) |
| `quiz_options` | — | **Orphaned** |
| `quiz_responses` | — | **Orphaned** |

### `restaurants`

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` identity | |
| `name` | `text` not null | Unique — a migration enforces it, so re-scraping cannot duplicate |
| `tag` | `text` not null | Category badge shown on the card ("Breakfast") |
| `details` | `text` not null `''` | |
| `brand_color` | `text` not null `'#141922'` | Hex; the client parses to `Color`. Falls back to a neutral panel grey when unreadable |
| `rating` | `numeric(2,1)` not null `0` | **Only 2 rows are non-zero.** See [Restaurant-Data.md](Restaurant-Data.md) |
| `latitude` / `longitude` | `double precision` not null | `0,0` means "unknown" — 474 rows are still there |
| `video_url` | `text` | The TikTok post. The stable identity of a row; never rewritten |
| `is_active` | `boolean` not null `true` | |
| `created_at` | `timestamptz` not null `now()` | |
| `search` | `tsvector` generated stored | `to_tsvector('simple', name ‖ tag ‖ details)`, GIN-indexed |
| `negara` | `text` not null `'Malaysia'` | Country |
| `negeri` | `text` | State. Added to catch the Penang-rows-tagged-Johor geocoding bug |

`video_url` also carries a unique constraint, and `rating` is denormalized
rather than aggregated from `reviews` — it is scraped data, not a computed
average, so no trigger maintains it.

### `swipes`

The busiest table in the product: it is simultaneously the deck's exclusion
list, the Liked tab, the Visited tab, the daily limit and the streak.

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` identity | |
| `user_id` | `uuid` not null | → `profiles (id)` on delete cascade |
| `restaurant_id` | `bigint` not null | → `restaurants (id)` on delete cascade |
| `liked` | `boolean` not null | Stays a boolean on purpose — see D5 |
| `super_like` | `boolean` not null `false` | **No longer written or read.** Kept for data safety; `wishlist_items` replaced it (D94) |
| `visited_at` | `timestamptz` | Stamped by `mark_visited` |
| `source` | `text` not null `'deck'` | Where the swipe came from |
| `swiped_at_latitude` / `_longitude` | `double precision` | Where the user was |
| `created_at` / `updated_at` | `timestamptz` not null | `updated_at` maintained by `touch_updated_at` |

`unique (user_id, restaurant_id)` — a re-swipe is an upsert. Partial indexes on
`(user_id) where liked` and `(user_id) where super_like` serve the Liked grid;
the second is now unused, alongside the column it indexes.

**`liked = false` and "no row" are different states.** `get_deck` excludes every
restaurant that has *any* swipe row, so writing `liked = false` retires a card
permanently (correct for unlike: the user saw it and said no) while deleting the
row makes it dealable again (correct for rewind: the swipe never happened).
That is why `undo_swipe` deletes — see D6.

### `wishlist_items`

Added 2026-09-05 (`20260905110000_wishlist_items.sql`). The checklist of places
to try — see [Wishlist.md](Wishlist.md) for why it is a table and not the
`super_like` flag it replaces.

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` identity | |
| `user_id` | `uuid` not null | → `profiles (id)` on delete cascade |
| `restaurant_id` | `bigint` | → `restaurants (id)` on delete cascade. Null only for a `manual` row |
| `title` | `text` not null | Stored, not only joined: a manual row has nothing to join to |
| `source` | `text` not null | `'swiped'` \| `'friend'` \| `'manual'` |
| `from_user_id` | `uuid` | → `profiles (id)` on delete **set null**. No write path yet |
| `eaten_at` | `timestamptz` | Null while the place is still to go |
| `created_at` | `timestamptz` not null | The list's order within each half |

`check (restaurant_id is not null or source = 'manual')` — the one shape the
table refuses.

`unique (user_id, restaurant_id) where restaurant_id is not null` — one row per
place per user, and any number of manual entries. Partial, so PostgREST cannot
name it as an upsert conflict target; the client inserts and swallows `23505`
instead. Plus `(user_id, eaten_at)` for the list's order and a plain index on
each foreign key.

Backfilled from `swipes where super_like` with the swipe's own `updated_at` as
`created_at`: **3 rows, 1 user**.

### `plans`

`id` identity, `owner_id` → `profiles`, `restaurant_id` → `restaurants` (both
cascade), `plan_date date`, `plan_time time` (null for "Late"), `time_label text
check in ('late')`, `with_friends boolean`, `status text check in
('planned','kept','cancelled')`, `created_at` / `updated_at`.

`plans_owner_restaurant_date_key` is the unique index behind D107 and the ON
CONFLICT target of `create_plan`. Also `plans_owner_date_idx` and
`plans_restaurant_idx`. `updated_at` rides the shared `touch_updated_at`
trigger.

`plan_date` is a `date`, never a timestamp: the client formats it from the
phone's local parts so a device east of UTC cannot post yesterday.

`plan_members` is `(plan_id, user_id)` with `status in
('invited','going','declined')` and `invited_at`, indexed on `user_id`.
`plan_time_votes` is `(plan_id, user_id)` plus `plan_time` / `time_label`.
Both are written by the Friends phase; they exist now so the invite flow lands
against a schema rather than beside one.

See [Plans-Calendar.md](Plans-Calendar.md).

### `profiles`

1:1 with `auth.users`, created by the `handle_new_user` trigger on insert.
Four concerns share the table:

- **Identity** — `name`, `role`, `avatar_url`, `onboarded_at`.
  A null `onboarded_at` is what routes a user into the wizard.
- **Ranking preferences** — `morning_mode`, `spice_bias`
  (`low`/`medium`/`high`), `nearby_focus`.
- **Diet & budget rules** (2026-09-05) — `halal_only bool not null default
  false`, `vegetarian bool not null default false`, `spice_level smallint`
  (`check between 1 and 4`, nullable), `budget_min int`, `budget_max int`
  (`check` that both are non-negative and `budget_min <= budget_max`). These
  are **hard filters** in `deck_scored`, not weights (D105).
  `spice_level` is the stored truth for spice and `spice_bias` is derived from
  it on every write (D104); a null `budget_max` beside a real `budget_min`
  means "and up", and both null means no answer.
- **Location** — `search_radius_km`, `last_latitude`, `last_longitude`,
  `last_place_name`, `located_at`, `location_source`. The stored fix is what
  lets a user who denied location still get a sensible deck.
- **Discovery filters** — `filter_cuisine_ids bigint[]`,
  `filter_dietary_tag_ids bigint[]`, `filter_min_rating`.
- **Passport (dead columns)** — `passport_latitude`, `passport_longitude`,
  `passport_place_name`. Nothing reads or writes them since D121; kept only
  because dropping a column destroys data.

Filters live on the profile rather than in device storage so they survive a
reinstall. A null passport latitude means Passport is off.

### `restaurant_images`

Doubles as the thumbnail cache state machine. `url` is permanent (a Supabase
Storage URL once cached); `source_url` and `source_expires_at` hold the
temporary, signed TikTok CDN URL and its expiry. `metadata_status`
(`pending`/`cached`/`failed`) and `refresh_attempts` (capped at 6) drive the
cron job. See [TikTok-Video.md](TikTok-Video.md).

## 3. Functions

28 in `public`. Grouped by what they serve:

### Deck and ranking

| Function | Signature | Notes |
|---|---|---|
| `get_deck` | `(p_limit int, p_latitude float8, p_longitude float8, p_seed bigint, p_radius_km int, p_local_hour int) → setof restaurants` | The deck. Rows come back in serve order — callers must not re-sort |
| `deck_scored` | `(p_latitude, p_longitude, p_seed, p_radius_km, p_local_hour) → table(restaurant_id, score, distance_km, swiped_at, liked)` | The scoring core `get_deck` and `get_top_picks` share |
| `get_top_picks` | `(p_limit int, p_latitude, p_longitude) → setof restaurants` | `get_deck`'s first query, small limit, no exhaustion fallback. Server caps at 20 |
| `deck_jitter` | `(p_id bigint, p_seed bigint) → float8` | Immutable per-session exploration noise |
| `haversine_km` | `(lat1, lng1, lat2, lng2) → float8` | Immutable. Distance without PostGIS — D9 |
| `nearest_restaurant_km` | `(p_latitude, p_longitude) → float8` | How far the nearest place is, for the "nothing nearby" copy |
| `tiktok_video_id` | `(video_url text) → bigint` | Immutable. Parses the post id, which increases with post time — the freshness signal |

`deck_scored` resolves location **server-side**, two steps since D121:

```sql
coalesce(
  p_latitude,                              -- the device's real fix
  (select m.last_latitude from me m)       -- last known
) as lat
```

`passport_latitude` used to head that list and no longer appears in it — see
the D121 note at the top. `search_restaurants` resolves it identically, and so
does the client when it labels a card's distance, which is the point: the
radius is applied from this origin, so anything that quotes a distance has to
quote it from here too.

The seed is derived from the current date in `Asia/Kuala_Lumpur`, so a
shortlist is stable for a day and rerolls at midnight for free.

#### The diet & budget predicates (2026-09-05)

All three sit in the `candidates` CTE alongside the radius and filter clauses,
so they bind the exhaustion fallback too (D34):

```sql
and (not c.halal_only or r.is_halal is true)
and (not c.vegetarian or exists (
      select 1 from public.restaurant_dietary_tags rdt
      join public.dietary_tags dt on dt.id = rdt.dietary_tag_id
      where rdt.restaurant_id = r.id and dt.slug = 'vegetarian'))
and (c.budget_max is null or r.price_from is null
     or r.price_from <= c.budget_max)
```

Three deliberate asymmetries (D105):

- Halal needs `is_halal is true` — an **unknown** certification does not pass a
  rule someone set to avoid eating where they cannot. 27 of 1 605 live rows are
  certified, which is why the column defaults to false.
- Vegetarian matches on the tag's **slug**, not a seeded id, so the predicate
  survives a reseed.
- An **unknown price passes** the budget ceiling. 1 419 of 1 605 rows have no
  `price_from`; dropping them would empty the deck for anyone who answered the
  budget question at all.

### Swiping

| Function | Signature | Notes |
|---|---|---|
| `record_swipe` | `(p_restaurant_id, p_liked, p_source, p_latitude, p_longitude, p_super_like) → void` | Upsert on `(user_id, restaurant_id)`. The client stopped sending `p_super_like` (D95); the parameter keeps its default |
| `undo_swipe` | `(p_restaurant_id bigint) → void` | **Deletes** the row. Raises `42501` with no authenticated user |
| `mark_visited` | `(p_restaurant_id bigint, p_visited boolean) → void` | Stamps or clears `visited_at` |
| `get_swipe_stats` | `() → table(swipes_today int, streak_days int)` | The daily-limit and streak chip |

### Reads

| Function | Signature |
|---|---|
| `get_liked_restaurants` | `(p_limit int, p_offset int) → setof restaurants` — `order by super_like desc, updated_at desc` |
| `get_visited_restaurants` | `(p_limit, p_offset) → setof restaurants` — **no caller** since D96 |
| `get_reviewed_restaurants` | `(p_limit, p_offset) → setof restaurants` — **no caller** since D96 |
| `get_super_liked_ids` | `() → setof bigint` — **no caller** since D94 |
| `search_restaurants` | `(p_query text, p_limit int, p_latitude, p_longitude, p_radius_km int, p_cuisine_id bigint) → setof restaurants` — caps at 100 |
| `get_cuisine_counts` | `() → table(cuisine_id, slug, label, emoji, restaurant_count, cover_url)` — ordered by count desc |
| `get_nearby` | `(p_latitude, p_longitude, p_radius_km double precision default 3, p_limit int default 60) → table(<restaurant columns>, restaurant_images jsonb, dishes jsonb, reviews jsonb, distance_km, open_now)` — ordered by distance, hard cap 200 |

Badges for saved places come from a second call rather than a flag on
`get_liked_restaurants` because that function returns `setof public.restaurants`,
which is what lets PostgREST embed images and reviews. Widening the return type
to carry a flag would cost the embed; a cheap second call is the smaller price.
That reasoning is unchanged — the second call is now a plain `wishlist_items`
select rather than `get_super_liked_ids` (D94).

`get_nearby` (2026-09-05, [Nearby-Map.md](Nearby-Map.md)) pays that price in the
other direction, deliberately. `distance_km` and `open_now` are the whole point
of the call, so it must return `table(...)` — and a table-returning RPC cannot
be `.select()`-embedded, so it aggregates images, dishes and reviews into
`jsonb` itself and still costs one round trip. It excludes inactive rows and
rows at `(0, 0)`, applies the same profile filters `deck_scored` applies, and
falls back to the caller's stored profile coordinates when both arguments are
null. `open_now` is `public.is_open_at`, which is null for unknown hours.
`get_cuisine_counts` and `get_top_picks` are retained even though the screens
that called them are gone (D102).

### Profile writes

| Function | Signature |
|---|---|
| `complete_onboarding` | `(p_name, p_cuisine_ids, p_dietary_ids, p_morning_mode, p_spice_bias, p_nearby_focus, p_radius_km, p_latitude, p_longitude, p_place_name, p_location_source, p_halal_only, p_vegetarian, p_spice_level, p_budget_min, p_budget_max, p_clear_budget) → profiles` |
| `update_preferences` | `(p_name, p_morning_mode, p_spice_bias, p_nearby_focus, p_radius_km, p_clear_radius, p_cuisine_ids, p_dietary_ids, p_halal_only, p_vegetarian, p_spice_level, p_budget_min, p_budget_max, p_clear_budget) → profiles` |
| `set_discovery_filters` | `(p_cuisine_ids, p_dietary_tag_ids, p_min_rating) → profiles` |
| `update_location` | `(p_latitude, p_longitude, p_place_name, p_source) → profiles` |

Each returns the whole updated `profiles` row, so the client refreshes its
cached profile from the write's own response instead of a follow-up read.
Both gained their last six parameters on 2026-09-05. Because Postgres
identifies a function by its argument list, appending parameters to a
`create or replace` would leave the old function behind as an **overload** and
make every named-argument call ambiguous — so each was dropped and recreated in
one transaction, with every old parameter kept in its old position. Callers did
not change.

`p_clear_budget` mirrors `p_clear_radius`. Between them, the budget's two ends
move as a **pair**: a non-null `p_budget_min` makes the pair authoritative and
the ceiling that arrives with it is written as-is, null included ("RM 10 and
up"). `p_clear_budget` is the only route back to "no answer", and it is what a
skipped first-run step sends.

When `p_spice_level` is given, both functions also write `spice_bias`
(1→`low`, 2→`medium`, 3 and 4→`high`) so `deck_scored`'s three-way term keeps
scoring (D104). The legacy `p_spice_bias` still works for a caller that has not
moved.

`update_preferences` needs an explicit `p_clear_radius` because null already
means "don't change this".

### Plans

| Function | Returns | Notes |
|---|---|---|
| `create_plan(p_restaurant_id, p_plan_date, p_plan_time, p_time_label, p_with_friends)` | `plans` | Upserts on `(owner_id, restaurant_id, plan_date)` (D107). A cancelled plan comes back `planned`. |
| `mark_plan_kept(p_today date default current_date)` | `integer` | Flips the caller's past `planned` rows to `kept` (D108). Returns the count. Called by the client on every load. |
| `plan_stats(p_today date default current_date)` | `table(plans_kept int, streak_weeks int)` | The You tab's two figures. The streak counts consecutive ISO weeks back from the most recent past week holding a plan; that week must be the current one or the one before, else the streak is 0. |
| `is_plan_member(p_plan_id bigint)` | `boolean` | RLS helper, `security definer` (D109). Checks `auth.uid()` inside itself, so it can only answer about the caller. |

`p_today` is passed by the client rather than defaulted, so "today" is the
phone's day and not the database server's.

### Triggers and internals

| Function | Purpose |
|---|---|
| `handle_new_user` | `security definer`. Creates the `profiles` row on `auth.users` insert |
| `sync_restaurant_cuisines` | `security definer`. Maps `restaurants.tag` through `cuisine_aliases` into `restaurant_cuisines` |
| `touch_updated_at` | Maintains `updated_at` |
| `get_thumbnail_refresh_key` | `security definer`. Vault fallback for the cron caller's auth |
| `record_thumbnail_refresh_failure` | Increments `refresh_attempts` |
| `submit_quiz_answer` | `(p_question_id, p_option_id) → quiz_options` — **orphaned** |

Only 4 functions are `security definer`; every one pins `set search_path = ''`.

## 4. RLS

20 policies. The split is uniform: **catalogue is world-readable, per-user data
is owner-only, and nothing in the catalogue is writable by a client at all.**

Catalogue reads — `select` to `anon, authenticated`:
`restaurants` (gated on `is_active`), `restaurant_images`, `reviews`,
`cuisines`, `cuisine_aliases`, `restaurant_cuisines`, `dietary_tags`,
`restaurant_dietary_tags`, `quiz_questions`, `quiz_options`.

Owner-only — to `authenticated`, `using` **and** `with check` on
`(select auth.uid())`:
`swipes` (all), `quiz_responses` (all), `profile_cuisines` (all),
`profile_dietary_tags` (all), `wishlist_items` (one policy per verb rather than
one `all`, because each verb was spelled out when the table was added),
`profiles` (`select` + `update` only — insert is the trigger's job, and there
is no delete policy because account deletion goes through the cascade),
`plans` (owner `all`).

Shared-by-invitation — to `authenticated`, resolved through the
`security definer` helper `is_plan_member` rather than through policies that
reference each other and recurse (D109): a member may select a `plan`; the
plan's owner inserts and deletes `plan_members` rows and a member selects and
updates their own; members select a plan's `plan_time_votes` and each writes
only their own.

`is_plan_member` keeps `EXECUTE` granted to `authenticated` — a policy
expression runs with the querying role's privileges, so revoking it makes
`select ... from public.plans` fail outright. The security advisor's
`authenticated_security_definer_function_executable` warning is therefore
accepted, as it already is for `get_ngap_count`; the reasoning is written into
the migration.

Catalogue writes happen only via migrations, the scraping scripts (which use
the publishable key for reads and SQL for writes) and `service_role`. There is
deliberately no `insert`/`update` policy for `authenticated` on any catalogue
table.

`anon` is included on catalogue reads for a future logged-out browse mode, which
does not exist yet.

## 5. Storage

One bucket: `restaurant-images`, public-read. Holds the cached TikTok
thumbnails. The path convention embeds the row id (`r11`…`r293`) and is
cosmetic — `restaurant_images.url` is the source of truth.

## 6. Scheduled work

One pg_cron job, `refresh-tiktok-thumbnails`: every 6 hours, POSTs
`{"batch": 25}` to the `refresh-thumbnails` edge function. Both the target URL
and the auth key are read from the environment's vault at run time; if either is
missing the job logs a warning and does nothing, so a fresh database never calls
production.

## 7. Known issues

- **`rating` is dead data.** 2 of 1,607 rows are non-zero, so
  `filter_min_rating` is a filter nobody can usefully set.
- **474 rows sit at `0,0`.** They are radius-invisible and distance-unrankable.
  `DeckRanker` gives them neutral half-credit offline so a missing geocode
  never locks a row out of the deck front, but the server-side radius filter
  has no such kindness.
- **The quiz tables are orphaned.** See [Quiz.md](Quiz.md).
- **Ten "unused index" advisor rows are noise.** The project has almost no
  traffic (1 profile, 33 swipes), so nothing has had a chance to use them.
  Re-check after real usage; do not drop them now.
- **Leaked-password protection is off** — a dashboard toggle, not schema.

## 8. Out of scope

- **PostGIS** — `haversine_km` is enough at this row count (D9).
- **A `ratings` aggregate trigger** — `rating` is scraped, not computed.
- **User-authored reviews** — `reviews.user_id` is a hook with no write path.
- **Price and opening-hours columns** — no source populates them, so the
  filters they would enable are not buildable.
- **Realtime** — nothing is collaborative yet; group dining would be first.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D1 | RLS keyed on `(select auth.uid())` is the security boundary; the publishable key ships in the binary. | locked 2026-08-22 |
| D3 | Ranking, radius, filters and swipe exclusion live in RPCs, not the client. | locked 2026-08-23 |
| D5 | `swipes.liked` stays boolean; `super_like` is a second flag, not an enum — an enum would break `get_deck`'s exhaustion branch, `get_liked_restaurants`, and the `swipes_user_liked_idx` partial index for no gain. | locked 2026-08-31 |
| D6 | `undo_swipe` deletes the row; unlike writes `liked = false`. Only a deleted row is dealt again. | locked 2026-08-31 |
| D9 | `haversine_km` in SQL, not PostGIS. | locked 2026-08-23 |
| D11 | Profile write RPCs return the whole `profiles` row, so the client never needs a follow-up read. | locked 2026-08-23 |
| D12 | `deck_scored` resolves passport → GPS → last-known server-side, so a client cannot override an active Passport. | locked 2026-08-31 |
| D104 | `spice_level` 1–4 is stored; `spice_bias` is derived from it inside the two write RPCs. | locked 2026-09-05 |
| D105 | `halal_only` / `vegetarian` / `budget_max` are hard predicates in `deck_scored`'s `candidates` CTE; unknown halal fails, unknown price passes. | locked 2026-09-05 |
| D13 | `get_super_liked_ids` is a separate call rather than widening `get_liked_restaurants`, to preserve PostgREST embeds. | locked 2026-08-31 |
| D102 | The Nearby map replaces the cuisine grid; no database object was dropped for it. | locked 2026-09-05 |
| D107 | A plan is one owner, one restaurant, one date — a unique index, and `create_plan`'s ON CONFLICT target. | locked 2026-09-06 |
| D108 | A past plan is kept unless cancelled; `mark_plan_kept()` flips it server-side on load. | locked 2026-09-06 |
| D109 | `is_plan_member` is a `security definer` helper rather than mutually recursive policies; its `authenticated` grant is required and its advisor warning accepted. | locked 2026-09-06 |
