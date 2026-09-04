Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [General/PLAN.md](../General/PLAN.md), [Backend-Schema.md](Backend-Schema.md), [TikTok-Video.md](TikTok-Video.md), [Likes-Visits.md](Likes-Visits.md), [Profile-Preferences.md](Profile-Preferences.md), [History/tinder-parity-plan.md](../History/tinder-parity-plan.md)

# Swipe Deck

The product's core surface: a Tinder-shaped card stack of restaurants, each
fronted by its TikTok video. Tab index 0.

Files: `lib/features/restaurants/presentation/swipe_deck.dart` (gesture and
motion), `swipe_card.dart` (one card), `state/deck_controller.dart` (all state),
`domain/deck_ranker.dart` (offline re-ranking),
`data/restaurant_repository.dart` + `swipe_repository.dart` (I/O).

## 1. Gestures

| Input | Threshold | Result |
|---|---|---|
| Drag right | `dx > 110` | Like |
| Drag left | `dx < -110` | Pass |
| Drag up | `dy < -140` **and** `|dx| < 110` | Super like |
| Release below threshold | — | Springs back |
| Tap the card | — | Full-screen TikTok player |
| Action bar buttons | — | Same path as a drag, via `_triggerAction` |

The up-swipe guard on `|dx|` matters: without it a diagonal fling reads as a
super like, and a super like is the scarce signal — it must be deliberate.

### Motion

One `AnimationController` at **640ms**, easing `easeInOutCubic`, interpolating
`_animationStartOffset → _animationEndOffset`.

- Exit offset: `(±460, -220)` for like/pass, `(0, -900)` for a super like —
  straight up, so the gesture and the animation agree.
- Rotation: `dx / 900`.
- Like/Nope stamp opacity: `dragPercentage = |travel| / 260`, clamped 0–1. The
  stamp only shows past 20px of travel, so a resting card is clean.
- Card lift: `easeOutCubic` over the same `dragPercentage`.
- A button press seeds a small offset (`±14`) before animating, so a tap and a
  drag leave along the same arc rather than the tap looking teleported.

### The match moment

A celebration overlay fires on every super like, and on **1 in 4** ordinary
likes (`_random.nextInt(4) == 0`). Not every like — a celebration that always
fires stops being one.

A rewind cancels any pending celebration: taking a swipe back is a "wait, no",
and celebrating the thing being undone reads as a bug.

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

## 3. Daily limit and streak

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

## 4. Rewind

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

### The header chip

`locationLabel` resolves in this order: the **passport pin** while one is set
(the deck is dealing that city and the chip must not claim the user's real
town), then the reverse-geocoded name of the last stored fix, then `'Nearby'`
for an account that has never granted location.

## 6. Card content

Media is the TikTok video when `video_url` is present, else a paged image
gallery (tap left/right half). Only the **foreground** card mounts a WebView;
the card behind shows a static thumbnail, so two videos never run at once. See
[TikTok-Video.md](TikTok-Video.md).

Over it: a tag pill, the restaurant name in the shared title style, rating and
distance pills, and a tap-to-expand panel revealing `details` and the review
carousel. The carousel blocks the deck's own pan gesture while the user is
scrolling reviews, otherwise a horizontal review swipe would pass a restaurant.

With 287 images and 6 reviews across 1,607 restaurants, the gallery and
carousel are empty for almost every card today — the video carries it.

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
