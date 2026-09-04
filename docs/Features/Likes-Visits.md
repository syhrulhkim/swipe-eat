Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Restaurant-Data.md](Restaurant-Data.md)

# Likes, Visits & Reviews

Tab index 2 ("Liked"). Three collections over one grid, plus the loop that
closes the product: the app sent you somewhere, so it asks whether you went.

Files: `lib/features/dashboard/presentation/likes_tab.dart`,
`likes_tab_view.dart`, `lib/features/restaurants/state/likes_controller.dart`,
`visit_prompt_controller.dart`, `data/visit_prompt_cache.dart`,
`presentation/visit_prompt_sheet.dart`, `data/likes_migration.dart`.

## 1. The three segments

`enum LikedSegment { liked, visited, reviewed }` over a single two-column photo
grid, with a sort dropdown and a filter sheet.

| Segment | RPC | Order |
|---|---|---|
| Liked | `get_liked_restaurants(p_limit, p_offset)` | `super_like desc, updated_at desc` |
| Visited | `get_visited_restaurants(p_limit, p_offset)` | Latest visit first |
| Reviewed | `get_reviewed_restaurants(p_limit, p_offset)` | Most recently reviewed first |

Segments are **lazily loaded**: the view calls `ensureLoaded` the first time
each is shown, so a user who never leaves Liked never pays for the other two.
A failure surfaces as that segment's own error state rather than as an unawaited
exception.

Super likes sort first in Liked, and are badged with a star. The badge data
comes from `get_super_liked_ids()` — a second, cheap call rather than a flag on
`get_liked_restaurants`, because that RPC returns `setof public.restaurants`,
which is what lets PostgREST embed images and reviews. Widening the return type
would cost the embed (D13).

## 2. Sorting and filtering

`enum LikedSort { latest, nearest, rating }`.

- **Latest** is the backend's own order — newest decision first — so it needs
  no client-side sort at all.
- **Nearest** keys on metres from the user, or `double.infinity` with no fix.
  Infinity everywhere degrades Nearest to the incoming order, which is the
  honest behaviour when nothing is actually nearer.
- **Rating** is present but effectively inert: 2 of 1,607 rows have one.

The filter sheet's two switches are **client-side** — they narrow what is
already on screen and do not refetch. That is the opposite of the deck's
discovery filters, which are server-side profile state
([Profile-Preferences.md](Profile-Preferences.md)). The distinction is
deliberate: this is a finite list the user already owns, so filtering it is a
view concern, not a query.

## 3. Unlike vs rewind

Both exist and they are **not** the same operation, which is the subtlest thing
in the schema:

| Action | Write | Effect on the deck |
|---|---|---|
| Unlike (here) | `record_swipe(liked: false)` | The row stays. The card is never dealt again — correct, the user saw it and said no |
| Rewind (deck) | `undo_swipe` → **deletes** the row | The card is dealable again — correct, the swipe never happened |

`get_deck` excludes every restaurant with *any* swipe row, which is what makes
the distinction load-bearing. See D6.

## 4. The visit prompt

The loop that closes the product. `VisitPromptController` ties the directions
button to the Visited list: it remembers who was sent where, and hands the
dashboard the one trip worth asking about on the next visit to the app.

```
tap "Get directions"  →  recordDirections()  →  device-local cache
        ↓
   maps app opens
        ↓
next app visit  →  next()  →  a ripe trip?  →  visit prompt sheet
                                                  ↓            ↓
                                            confirm()      dismiss()
                                                ↓              ↓
                                          mark_visited     forget it
                                          → Visited tab
```

Design notes worth keeping:

- **Not a `ChangeNotifier`** — nothing watches it. The dashboard pulls when it
  becomes visible, and everything it writes is either device-local or already
  broadcast by the backend.
- `recordDirections` **skips signed-out users**: `mark_visited` needs an
  account, so there would be no way to answer the question later.
- Only fires when the maps app **actually opened**, not on tap.
- `confirm()` clears the cache **only after the write lands**, so a failed call
  leaves the prompt to be asked again rather than losing the visit silently.
- `dismiss()` records nothing. "I didn't go" is not data worth keeping; the
  trip just stops being an open question.
- One prompt at a time — "the one trip worth asking about", not a queue the
  user has to clear.

## 5. The likes migration

`data/likes_migration.dart` exists because likes predate the backend: an
earlier build kept them in device storage. It moves any locally stored likes
into `swipes` once, on first run against the real backend. Covered by
`test/features/restaurants/likes_migration_test.dart`.

It is a one-shot compatibility shim, not part of the steady state, and can be
deleted once no install predates the migration.

## 6. Known gaps

- **The Reviewed segment is nearly always empty** — 6 reviews exist across the
  whole catalogue, and there is no write path for a user to add one
  (`reviews.user_id` is a hook only). The segment is built for a feature that
  does not exist yet.
- **Rating sort is inert** for the same reason it is inert everywhere.
- `visited_at` is a single timestamp, so a second visit overwrites the first —
  no visit history.

## 7. Out of scope

- **User-authored reviews.** The schema hook and the Reviewed segment are both
  ready; the write path is not built.
- **Collections / lists** beyond the three segments.
- **Sharing a liked place** out of the app.

## 8. Decision log

| ID | Decision | Status |
|---|---|---|
| D6 | Unlike writes `liked = false`; rewind deletes. Only a deleted row is dealt again. | locked 2026-08-31 |
| D13 | Super-like badges come from a separate `get_super_liked_ids` call, to preserve PostgREST embeds. | locked 2026-08-31 |
| D24 | The Liked filter sheet is client-side; the deck's discovery filters are server-side profile state. A finite owned list is a view concern. | locked 2026-08-31 |
| D25 | Segments load lazily — a user who never opens Visited never pays for it. | locked 2026-08-31 |
| D26 | The visit prompt only arms when the maps app actually opened, and only for signed-in users. | locked 2026-08-31 |
| D27 | "I didn't go" records nothing — a dismissal is not data. | locked 2026-08-31 |
| D28 | `confirm()` clears its cache only after the write lands, so a failure re-asks rather than losing the visit. | locked 2026-08-31 |
