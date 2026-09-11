Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Wishlist.md](Wishlist.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Restaurant-Data.md](Restaurant-Data.md)

# Likes, Visits & Reviews

> **Changed 2026-09-10.** The Bites tile is a **photo over a caption strip**
> — name and cuisine on their own dark ground under the picture, not laid over
> it — with an **ember check** in the photo's corner as the saved mark. The
> wishlist bookmark badge is removed, not hidden (D125).
>
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
saved check** — the wishlist row's 26 px ember tick, in the photo's top-right
(D125). One further mark sits on the photo:

- the **planned day pill** (`.planned`) in the top-left — "Today", "Tonight",
  "Fri 4". **Live since 2026-09-06**: `PlansController` fills it, see
  [Plans-Calendar.md](Plans-Calendar.md).

The tile splits **photo above, caption below**: the picture fills the top of
the tile and the name and second line sit on a solid `kSurfaceDark` strip
under it, so neither needs a scrim — there is no `PhotoTileScrim` and no
`BiteNotch` on this tile any more. The strip is sized to its text and the
photo takes the rest, which is what lets a 2× text scale grow the caption
instead of overflowing the tile — and why the name is one line, not two. The
tile is a clipped `Container` on `kSurfaceDark` at `kRadiusPanel`, and its
hairline outline is a **`foregroundDecoration`**: a border in the background
decoration would inset the square-cornered photo one pixel inside the stroke,
and the photo would then overpaint it at every corner.

The tile's second line is **"Cuisine · Neighbourhood"** in `kCreamMuted`,
dropping the neighbourhood rather than dangling a separator when the row has
none. The distance and rating that used to live there are not in the design.
The grid runs at `childAspectRatio: 0.9`.

The two marks sit **inside the photo**, both inset 8: `_SavedCheck` — a 26 px
(`kCheckCircleSize`) ember disc with a 14 px check — at the top right, and
`_PlannedPill` at the top left. Both are `IgnorePointer` under an opaque hit
test, so a tap on either lands on the tile rather than falling through.

### Retired

| Gone from the client | Still in the database |
|---|---|
| The Visited grid and `visitedRestaurants()` | `get_visited_restaurants`, `swipes.visited_at`, and `mark_visited` — which the **visit prompt** (§4) still writes |
| The Reviewed grid and `reviewedRestaurants()` | `get_reviewed_restaurants`, `reviews` |
| `LikedSort` and the sort dropdown | — |
| The filter sheet and "With TikTok review" | — |
| The per-tile unlike / mark-visited buttons | — |
| The wishlist bookmark badge on a tile (D125) | `wishlist_items`, which the Wishlist screen still reads |

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
stays lit after taking you away is claiming to be a filter it is not. It is a
plain `context.push('/wishlist')` and the tab **does not refresh on the way
back** — with the bookmark badge gone (D125) there is nothing on a tile that a
wishlist edit could change. A pull-to-refresh is the way to force one.

Tapping the chosen plan chip again returns to All — without that there is no
way out of a filter except finding All again.

`plannedRestaurantIds` is **live since 2026-09-06**: `PlansController` pushes
the ids of the user's *upcoming* plans through `setPlannedRestaurantIds` on
every load and every change — see [Plans-Calendar.md](Plans-Calendar.md). A
dinner that has already happened is a visit rather than a plan, so it leaves
the set. With nothing planned, "Planned" is still correctly empty and "Not
planned yet" correctly everything.

Null `isHalal` means "the caption never said", which is not a yes — a Halal
filter that returns maybes is not a filter.

Filtering stays **client-side**, the opposite of the deck's discovery filters,
which are server-side profile state
([Profile-Preferences.md](Profile-Preferences.md)). The distinction is
deliberate: this is a finite list the user already owns, so filtering it is a
view concern, not a query.

A **pull down on the grid** refreshes too — `Could not load your bites.` on
failure, the same string the first load uses — and it refreshes *both* caches — the
likes behind the tiles and the calendar behind the day badges and the Planned
chips. The tab is the two of them crossed, so reloading one would leave the
other's stale answer on screen. Every branch of the grid is
`AlwaysScrollableScrollPhysics`, the empty state included: a list shorter than
its viewport does not scroll, and "no bites yet" is exactly the state a user
pulls in after saving something on another device.

## 3. Unlike, and the rewind that is not there

| Action | Write | Effect on the deck |
|---|---|---|
| Unlike (here) | `record_swipe(liked: false)` | The row stays. The card is never dealt again — correct, the user saw it and said no |
| ~~Rewind (deck)~~ | ~~`undo_swipe` → **deletes** the row~~ | **No UI since D84.** The deck's action bar is Skip / Ngap! / Later, and nothing calls `undo_swipe`; it is an orphaned function in the database. |

`get_deck` excludes every restaurant with *any* swipe row, which is what made
the distinction load-bearing while both existed. With rewind gone, an unlike is
final: there is no path back to a card the user has answered. See D6, D84.

## 4. The visit prompt

The loop that closes the product. `VisitPromptController` ties the directions
button to the Visited list: it remembers who was sent where, and hands the
dashboard the one trip worth asking about on the next visit to the app.

```
tap "Get directions"  →  recordDirections()  →  device-local cache
        ↓                                              ↓
   maps app opens                                      │
                              a past plan ────────────┐│
                              (next_visit_prompt)     ↓↓
next app visit  →  next()  →  a ripe trip?  →  visit prompt sheet
                                                  ↓            ↓
                                            confirm()      dismiss()
                                                ↓              ↓
                                     record_visit_answer   forget it, and
                                     visited_at + stars    cancel the plan
                                     → Visited tab         it was about
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
- `dismiss()` records nothing **for a walk-in**. "I didn't go" is not data
  worth keeping when nobody ever claimed otherwise. For a plan it is: D108
  flipped that plan to `kept` on an assumption, and this is the first evidence
  either way, so the plan goes to `cancelled` (D147).
- One prompt at a time — "the one trip worth asking about", not a queue the
  user has to clear.

### The stars (D147)

Since 2026-09-11 the same sheet also asks *how was it*: five stars and one
optional line, both skippable. The whole answer goes in one call,
`record_visit_answer(p_restaurant_id, p_went, p_rating, p_body, p_plan_id)` —
"I didn't go", "I went", and "I went and here are four stars" are the same
question answered three ways, and none of them is worth a second round trip.

Three things follow from a star:

1. The review lands in `reviews`, one row per person per place — a second visit
   **edits** the first rather than stacking.
2. `restaurants.rating` becomes the average of those stars, by trigger. The
   column used to be an import that was non-zero on 2 of 1 607 rows, which is
   why the deck's quality term did nothing and its unrated-row jitter did all
   the work. From here it means *what our users say*.
3. **Friends can read it; nobody else can.** The `reviews` read policy fences
   an authored row behind the same accepted-pair test `friends_who_liked`
   uses. The six seeded snippets have a null author and stay public — though
   all six sit on inactive restaurants, so in practice nothing reads them.

The question about a **plan** comes from `next_visit_prompt(p_today)`: the
caller's most recent plan whose day has passed, which they have not rated, no
older than **14 days**. Past that the answer is a guess, and a guess is worse
than silence in the one place the app gets a real opinion. The lookup runs
**once per app run** — `_maybeAskAboutVisit` fires on every resume and a plan
does not become askable between two of them.

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
- **Reviews have no read surface.** They are written now (D147) and they feed
  `restaurants.rating`, but no screen shows a friend's stars back to anyone —
  the detail page dropped its review card in the redesign and has not been
  given a new one.
- `visited_at` is a single timestamp, so a second visit overwrites the first —
  no visit history.
- ~~**Planned is inert**~~ — resolved 2026-09-06 by
  [Plans-Calendar.md](Plans-Calendar.md). Both chips and the day pill are fed
  from real plans.

## 7. Out of scope

- ~~**User-authored reviews.**~~ Built 2026-09-11 (D147); see §4.
- **Collections / lists** beyond Bites and the wishlist.
- **Sharing a liked place** out of the app. The *wishlist* shares as plain
  text; a single place does not.

## 8. Decision log

| ID | Decision | Status |
|---|---|---|
| D6 | Unlike writes `liked = false`; ~~rewind deletes. Only a deleted row is dealt again.~~ | **superseded in the client by D84** — rewind is gone; unlike still writes `liked = false` |
| D13 | Badges for saved places come from a separate call, to preserve PostgREST embeds on `get_liked_restaurants`. The reasoning stands; the call is now a `wishlist_items` read rather than `get_super_liked_ids` (D94). | locked 2026-08-31 |
| D24 | The Liked filter sheet is client-side; the deck's discovery filters are server-side profile state. A finite owned list is a view concern. | locked 2026-08-31 |
| D25 | Segments load lazily — a user who never opens Visited never pays for it. | locked 2026-08-31 |
| D26 | The visit prompt only arms when the maps app actually opened, and only for signed-in users. | locked 2026-08-31 |
| D147 | The visit prompt asks for **1–5 stars and an optional line**, and asks about a past **plan** as well as a walk-in. A review is visible to the author's friends only; `restaurants.rating` becomes the average of those stars by trigger; "I didn't go" on a plan corrects D108's assumed `kept` to `cancelled`. | locked 2026-09-11 |
| D27 | "I didn't go" records nothing — a dismissal is not data. | locked 2026-08-31 |
| D96 | The design's chip row replaces the Liked / Visited / Reviewed segments, and Visited and Reviewed leave the client entirely. Their RPCs and data stay. The three plan chips are one enum, not three booleans; "Wishlist →" navigates and never holds a pressed state. | locked 2026-09-05 |
| D125 | The Bites tile is a **photo over a solid caption strip**, and its saved mark is an **ember check drawn in the photo's corner** — the wishlist row's tick, so "saved" and "done" are one family of mark. The **wishlist bookmark badge is removed**, not hidden (D84): every tile in Bites is saved, the Wishlist chip is one tap away, and a second badge in the same corner was a collision the prototype's own mask never resolved. This supersedes D79 **on the grid tile only** — a notch-revealed disc at inset 6 / radius 30 is a quarter-circle hanging off the corner, not the reference's full circle, and a notch *and* a badge in one corner would be two saved-marks. The bite stays on the detail hero and the auth blob. With the badge gone, the tab no longer refreshes on the way back from the Wishlist; `LikesController.isSavedForLater` keeps its wishlist callers and tests but has no reader in the tab. | locked 2026-09-10 |
| D28 | `confirm()` clears its cache only after the write lands, so a failure re-asks rather than losing the visit. | locked 2026-08-31 |
