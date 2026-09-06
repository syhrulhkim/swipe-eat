Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [General/PLAN.md](../General/PLAN.md), [Backend-Schema.md](Backend-Schema.md), [TikTok-Video.md](TikTok-Video.md), [Likes-Visits.md](Likes-Visits.md), [Profile-Preferences.md](Profile-Preferences.md), [History/tinder-parity-plan.md](../History/tinder-parity-plan.md)

# Swipe Deck

The product's core surface: a card stack of restaurants, each fronted by its
TikTok video. Tab index 0.

> **Retired 2026-09-04 (D84).** Super like, rewind, the 50-swipe daily limit,
> the deck streak and the match moment are **gone** — the new design has none
> of them, and a control for a retired feature is worse than a missing one. The
> up gesture is rebound to **Later** (D85). Sections 3, 4 and "The match
> moment" are kept below as history, struck through.

Files: `lib/features/restaurants/presentation/swipe_deck.dart` (gesture and
motion), `swipe_card.dart` (one card), `state/deck_controller.dart` (all state),
`domain/deck_ranker.dart` (offline re-ranking),
`data/restaurant_repository.dart` + `swipe_repository.dart` (I/O).

## 1. Gestures

| Input | Threshold | Result |
|---|---|---|
| Drag right | `dx > 110` | Like |
| Drag left | `dx < -110` | Pass |
| Drag up | `dy < -140` **and** `|dx| < 110` | **Later** — save without deciding |
| Release below threshold | — | Springs back |
| Tap the card | — | Full-screen TikTok player |
| Action bar buttons | — | Same path as a drag, via `_triggerAction` |

The up-swipe guard on `|dx|` matters: without it a diagonal fling reads as a
Later, and Later is a decision to make later — it must be deliberate (D14).

The action bar is the design's **three circles**: a 56 px ghost Skip, the 72 px
gradient **Ngap!** button carrying the word, and a 56 px ghost Later. It was
five controls — rewind, Pass, the super-like star, Like — until D84.

### Motion

One `AnimationController` at **640ms**, easing `easeInOutCubic`, interpolating
`_animationStartOffset → _animationEndOffset`.

- Exit offset: `(±460, -220)` for Ngap/Skip, `(0, -900)` for Later — straight
  up, so the gesture and the animation agree.
- Rotation: `dx / 900`.
- Like/Nope stamp opacity: `dragPercentage = |travel| / 260`, clamped 0–1. The
  stamp only shows past 20px of travel, so a resting card is clean.
- Card lift: `easeOutCubic` over the same `dragPercentage`.
- A button press seeds a small offset (`±14`) before animating, so a tap and a
  drag leave along the same arc rather than the tap looking teleported.

### ~~The match moment~~ — removed 2026-09-04 (D84)

~~A celebration overlay fires on every super like, and on 1 in 4 ordinary
likes.~~ `_MatchOverlay` is gone. A restaurant cannot swipe back, so there was
never a match to celebrate, and the new design does not stop the flow to say
otherwise.

It was also the deck's only route to **Get directions**. That affordance
survives on the card itself and on the detail page, which is where the
visit-prompt feature is triggered from — so removing the overlay did not take
the visit prompt with it.

## 2. Ranking

The deck arrives **pre-ranked from `get_deck`** and the client must not re-sort
it. Signals, adapted from how Tinder describes its post-Elo ranking:

| Signal | Weight | How |
|---|---|---|
| Exploration | 0.35 | Per-session random jitter, so each session sees a rotated order |
| Proximity | 0.30 | Exponential decay, half-life **12 km** |
| Freshness | 0.20 | TikTok post id (which increases with post time), else row id |
| Quality | 0.15 | `rating`, when one exists |
| Recently seen | −1.25 | Sinks to the back rather than being re-shown |

Those weights are `DeckRanker`'s — the **offline** ranker
(`domain/deck_ranker.dart`), which re-ranks a cached deck when there is no
server to ask. The server's `deck_scored` is the live path and additionally
applies `morning_mode`, `spice_bias`, the taste signal from onboarding, the
radius, and the discovery filters.

Two deliberate details in the ranker:

- The recently-seen penalty (1.25) is strictly larger than the sum of the four
  weights (1.00), so a perfect-scoring seen card still ranks behind the worst
  unseen card, while seen cards keep their relative order among themselves.
- Restaurants at `(0, 0)` are treated as "location unknown" and get **neutral
  half-credit** on proximity, so a missing geocode never locks a row out of the
  deck front. 474 rows depend on this.

The seed is derived from the current date in `Asia/Kuala_Lumpur`, so the order
is stable for a day and rerolls at midnight for free.

## 3. ~~Daily limit and streak~~ — removed 2026-09-04 (D84)

> History. None of the code below exists any more: the constant, the
> `get_swipe_stats` call, `swipesLeft`, `outOfSwipes`, the flame chip and the
> out-of-swipes empty state are all gone.

`DeckController.dailySwipeLimit = 50`, enforced **client-side** off
`get_swipe_stats`.

- `swipesLeft` is null while the count is unknown (never loaded, or the stats
  call failed). `outOfSwipes` is true **only** when the count is known and
  spent — an unknown count stays swipeable, because a stats hiccup must never
  brick the deck.
- `streakDays` is consecutive days with at least one swipe, shown as a flame in
  the header.
- Out of swipes, the deck stops dealing but **rewind stays offered** — taking a
  swipe back refunds it.

## 4. ~~Rewind~~ — removed 2026-09-04 (D84)

> History. `DeckController.rewind`, `canRewind` and every affordance that
> offered it are gone. `undo_swipe` still exists on the database, unused.

`DeckController.rewind()` → `undo_swipe`, which **deletes** the row rather than
writing `liked = false`. `get_deck` excludes every restaurant with any swipe
row, so an "undone" card would otherwise never be dealt again (D6).

**The race this has to survive:** `recordSwipe` is optimistic — the card flies
out and the write follows. An undo firing before that write lands would delete
nothing, and then the like would insert, leaving the row behind and the card
gone for good. The controller holds the in-flight future per restaurant and
awaits it before deleting.

Rewind also works from the exhausted-deck state, where it brings the very last
swipe back.

## 5. Load, concurrency and staleness

`load()` is guarded by `_loadGeneration`: only the newest request may publish
its result, so a slow response from an earlier call can never overwrite a
fresher deck. Init and every retry button share the path.

The deck is re-dealt when any **deck-shaping** profile field changes — radius,
discovery filters, passport. The tabs live in an `IndexedStack` that never
re-inits, so these have to be listened for; they are server-side filters, and
stale cards would break the promise they make. `lastPlaceName` and the stored
fix are deliberately excluded, since every load syncs those anyway and
including them would re-deal on every load.

### Offline

`deck_cache.dart` persists the last dealt deck in `shared_preferences` under
`deck_cache_v1`, scoped to the user id and expiring after **7 days** — a deck
from last month knows nothing about where the user is now.

When cards come off the device, `isStale` is true and `stalenessLabel` renders a
visible notice. A saved deck presented as live is a lie about how close those
places are.

### The header

The design's `.topbar`: a place icon, the location on one line and
"within 3 km · dinner" under it, and the **Filters** button with its count dot.
Nothing else — Settings moved to the You tab on 2026-09-05, because the design
gives the swipe screen one button.

`locationLabel` is the reverse-geocoded name of the last stored fix, else
`'Nearby'` for an account that has never granted location (the passport pin
that used to come first was retired with D84). The second line is the profile's
`search_radius_km` ("any distance" when unset) and `mealLabel(now)` from
`domain/meal_label.dart` — breakfast before 11, lunch to 15, tea to 18, dinner
to 22, supper otherwise.

## 6. Card content

Media is the TikTok video when `video_url` is present, else a paged image
gallery (tap left/right half). Only the **foreground** card mounts a WebView;
the card behind shows a static thumbnail, so two videos never run at once. See
[TikTok-Video.md](TikTok-Video.md).

Over it, low over the scrim, the design's **info block** (`RestaurantInfoBlock`
in `swipe_card.dart`), changed 2026-09-05 (D93):

- **Tags** — a fresh-tinted "Open till 2 am" chip when the place is open right
  now (the only fresh thing on the screen, `AppTagChip.fresh`), the cuisine, and
  "Halal" when the caption says so. A closed place gets no chip: on a card you
  are being dealt, "closed" is a reason to skip, and the detail screen says when
  it opens.
- **Name** — Bricolage 34 px, weight 800, two lines at most.
- **Meta** — `**1.2 km** · Masai` and `**From RM 19**`. Each part hides when
  unknown; the distance always shows.

A tap on the block opens the restaurant's screen; a tap on the clip opens the
fullscreen player. The card carries **no buttons**: the three actions are
`DeckActionBar` under the deck (`swipe_deck.dart`), so the card behind is the
same surface as the card in front. The tap-to-expand panel, the `details`
paragraph and the review carousel are gone from the card — with 6 reviews across
1,607 rows the carousel was empty on almost every card, and its pan-gesture lock
(the carousel had to block the deck's own drag) went with it. Details live on
the detail screen — [Restaurant-Detail.md](Restaurant-Detail.md), built
2026-09-06.

Where the facts come from: [Restaurant-Data.md §2a](Restaurant-Data.md) — the
opening span, the lowest price, halal and the neighbourhood are parsed once
from the caption into columns (D91). Open state is computed the same way on the
server (`is_open_at`, Kuala Lumpur time) and on the device (`OpeningHours` in
`domain/opening_hours.dart`, device-local clock — D92); the card uses the Dart
one so a cached deck says the same thing a fresh one would.

## 7. Empty and error states

| State | Shown |
|---|---|
| Loading | Skeleton, not a spinner over an empty deck |
| Exhausted | "No more cards" + rewind, if a swipe exists to take back |
| Out of swipes | Limit reached + rewind, which refunds one |
| Error | Message + retry, sequenced through `_loadGeneration` |
| Stale | The deck plus a visible staleness label |
| Nothing in radius | Uses `nearest_restaurant_km` to say how far the nearest place actually is |

## 8. Known gaps

- The daily limit is client-side only. A modified client can exceed 50; there
  is no server-side check. Acceptable while the limit is a pacing device rather
  than a paywall.
- The match celebration's 1-in-4 rate is a magic number with no tuning behind
  it.
- Ranking's quality signal is inert: only 2 of 1,607 rows have a rating.

## 9. Out of scope

- **Mutual matching, chat, "Likes You", Boost** — a restaurant never swipes
  back. See [History/tinder-parity-plan.md](../History/tinder-parity-plan.md).
- **Server-enforced swipe limits** — see above.
- **Undo history deeper than one** — rewind is one step, like Tinder's.

## 10. Decision log

| ID | Decision | Status |
|---|---|---|
| D3 | Ranking lives in `get_deck`; the client renders serve order and must not re-sort. | locked 2026-08-23 |
| D6 | Rewind deletes the swipe row; unlike writes `liked = false`. | locked 2026-08-31 |
| D14 | The up-swipe super like is guarded on `|dx| < 110` so a diagonal fling cannot spend the scarce signal. | locked 2026-08-31 |
| D15 | Celebrate every super like but only 1 in 4 likes — an always-on celebration stops being one. | locked 2026-08-31 |
| D16 | An unknown swipe count stays swipeable; only a known-and-spent count blocks. A stats failure must not brick the deck. | locked 2026-08-31 |
| D17 | A stale (cached) deck is always labelled as stale, never presented as live. | locked 2026-08-30 |
| D18 | `DeckRanker` gives unlocated rows neutral half-credit rather than excluding them. | locked 2026-08-31 |
| D92 | Open state is computed identically in SQL (`is_open_at`, Asia/Kuala_Lumpur) and Dart (`OpeningHours`, device clock); an unknown span answers null and the chip hides. | locked 2026-09-05 |
| D93 | The card carries no controls and no expandable panel: the action bar lives under the deck, the info block opens the detail screen, details and reviews live there. | locked 2026-09-05 |
