Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [Wishlist.md](Wishlist.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Restaurant-Data.md](Restaurant-Data.md)

# Likes, Visits & Reviews

> **Changed 2026-09-05.** The Liked | Visited | Reviewed segments are gone from
> the client, replaced by the design's chip row (D96). **Visited and Reviewed
> are retired from the UI** — their RPCs and data are untouched, nothing calls
> them. So are the sort dropdown, the filter sheet and the per-tile buttons.
> The Later store moved to `wishlist_items` (D94); see
> [Wishlist.md](Wishlist.md).
>
> **Changed 2026-09-04.** The tab is titled **"Your bites"**. The super-like
> star, the "Must try only" filter and `isSuperLiked` are gone with the feature
> (D84); the **bite notch** marks a saved tile instead.

Tab index 2 ("Bites"). One grid of the places you have bitten, filtered by a
row of chips — plus the loop that closes the product: the app sent you
somewhere, so it asks whether you went.

Files: `lib/features/dashboard/presentation/likes_tab.dart`,
`likes_tab_view.dart`, `lib/features/restaurants/state/likes_controller.dart`,
`visit_prompt_controller.dart`, `data/visit_prompt_cache.dart`,
`presentation/visit_prompt_sheet.dart`, `data/likes_migration.dart`.

## 1. The grid

One collection, one two-column photo grid:
`get_liked_restaurants(p_limit, p_offset)`, ordered `super_like desc,
updated_at desc` server-side. The client does not re-sort it — Latest was the
only sort anyone could use and it was already the backend's order.

Every tile in Bites is a place the user saved, so **every tile carries the
bite**. Two further marks sit on it:

- the **wishlist bookmark** (`.wish`) in the top-right, when the place is still
  on the wishlist. Painted over the notch rather than inside it, because a
  28 px badge at that inset falls wholly within the 30 px bite;
- the **planned day pill** (`.planned`) in the top-left. Always absent today —
  see §2.

The tile's second line is **"Cuisine · Neighbourhood"**, dropping the
neighbourhood rather than dangling a separator when the row has none. The
distance and rating that used to live there are not in the design.

### Retired

| Gone from the client | Still in the database |
|---|---|
| The Visited grid and `visitedRestaurants()` | `get_visited_restaurants`, `swipes.visited_at`, and `mark_visited` — which the **visit prompt** (§4) still writes |
| The Reviewed grid and `reviewedRestaurants()` | `get_reviewed_restaurants`, `reviews` |
| `LikedSort` and the sort dropdown | — |
| The filter sheet and "With TikTok review" | — |
| The per-tile unlike / mark-visited buttons | — |

`RestaurantListController` lost its only two callers with the two grids. It is
left in place rather than deleted, as the shape any future lazily loaded list
would want.

## 2. The chip row

`.chiprow` — five 36 px pills, scrolling sideways, bleeding to both screen
edges. Ember once chosen, a hairline outline until then. Drawn at 36 and tapped
at 44.

| Chip | What it does |
|---|---|
| **All** | The default. |
| **Not planned yet** | Keeps tiles *not* in `LikesController.plannedRestaurantIds`. |
| **Planned** | Keeps tiles that are. |
| **Wishlist →** | Pushes `/wishlist`. Never holds the pressed fill. |
| **Halal** | Keeps `isHalal == true` only. |

Three of them are one question asked three ways, so they are one
`enum BitesPlanFilter { all, notPlanned, planned }` rather than three booleans
that can contradict each other. Halal is a separate toggle because it narrows
any of the three. **Wishlist →** is in neither: it navigates, and a chip that
stays lit after taking you away is claiming to be a filter it is not.

Tapping the chosen plan chip again returns to All — without that there is no
way out of a filter except finding All again.

`plannedRestaurantIds` is **empty today**; the plans phase feeds it through
`setPlannedRestaurantIds`. Both chips are real, tested code that starts working
the day the ids arrive. With nothing planned, "Planned" is correctly empty and
"Not planned yet" is correctly everything.

Null `isHalal` means "the caption never said", which is not a yes — a Halal
filter that returns maybes is not a filter.

Filtering stays **client-side**, the opposite of the deck's discovery filters,
which are server-side profile state
([Profile-Preferences.md](Profile-Preferences.md)). The distinction is
deliberate: this is a finite list the user already owns, so filtering it is a
view concern, not a query.

Leaving the Wishlist refreshes the tab, because crossing a place off over there
clears its bookmark here.

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

- **Visited has no surface.** `mark_visited` is still written by the visit
  prompt, and `swipes.visited_at` still fills up, but nothing shows it back to
  the user. The design does not ask for a Visited list; the wishlist's eaten
  half is the nearest thing it has.
- **Reviews have no surface either**, and no write path — 6 exist across the
  whole catalogue and `reviews.user_id` is a hook only.
- `visited_at` is a single timestamp, so a second visit overwrites the first —
  no visit history.
- **Planned is inert** until the plans phase lands (§2).

## 7. Out of scope

- **User-authored reviews.** The schema hook is ready; the write path is not
  built.
- **Collections / lists** beyond Bites and the wishlist.
- **Sharing a liked place** out of the app. The *wishlist* shares as plain
  text; a single place does not.

## 8. Decision log

| ID | Decision | Status |
|---|---|---|
| D6 | Unlike writes `liked = false`; rewind deletes. Only a deleted row is dealt again. | locked 2026-08-31 |
| D13 | Badges for saved places come from a separate call, to preserve PostgREST embeds on `get_liked_restaurants`. The reasoning stands; the call is now a `wishlist_items` read rather than `get_super_liked_ids` (D94). | locked 2026-08-31 |
| D24 | The Liked filter sheet is client-side; the deck's discovery filters are server-side profile state. A finite owned list is a view concern. | locked 2026-08-31 |
| D25 | Segments load lazily — a user who never opens Visited never pays for it. | locked 2026-08-31 |
| D26 | The visit prompt only arms when the maps app actually opened, and only for signed-in users. | locked 2026-08-31 |
| D27 | "I didn't go" records nothing — a dismissal is not data. | locked 2026-08-31 |
| D96 | The design's chip row replaces the Liked / Visited / Reviewed segments, and Visited and Reviewed leave the client entirely. Their RPCs and data stay. The three plan chips are one enum, not three booleans; "Wishlist →" navigates and never holds a pressed state. | locked 2026-09-05 |
| D28 | `confirm()` clears its cache only after the write lands, so a failure re-asks rather than losing the visit. | locked 2026-08-31 |
