Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Friends.md](Friends.md), [Swipe-Deck.md](Swipe-Deck.md), [Restaurant-Data.md](Restaurant-Data.md), [Wishlist.md](Wishlist.md), [TikTok-Video.md](TikTok-Video.md), [../Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md)

# Restaurant detail

One restaurant, top to bottom: the clip, what it costs and how many people
have bitten it, what they order, and the one thing to do next. Screen **S3** in
`docs/Redesign/assets/ngap-app-screens.html`.

Route `/restaurant/:id`. A tap from the deck carries the whole row as the
router's `extra`, so the screen paints with no wait; a deep link carries only
the id and the row is fetched.

Files: `lib/features/restaurants/presentation/restaurant_detail_page.dart`,
`restaurant_detail_route.dart`, and the pieces under `presentation/detail/`
(`detail_hero.dart`, `facts_strip.dart`, `dish_list.dart`,
`about_paragraph.dart`, `friends_bite_row.dart`, `detail_cta_bar.dart`).

## 1. What the screen is made of

| Band | What it holds | Source |
|---|---|---|
| **Hero** | The clip, or the first photo, or the TikTok placeholder. Two scrims, the sound pill, back + wishlist buttons, and low over the deep end the tags, the 36 px name and one meta line | `videoUrl`, `imageUrls`, `tag`, `isHalal`, `neighbourhood`, `hours`, the device fix |
| **Facts** | Two tiles at most: the cheapest dish, and the ngap count | `priceFrom`, `RestaurantRepository.ngapCount` |
| **What people bite** | The dishes, each with a thumb, a name, a description and a price | `dishes` |
| **About** | The scraped caption, three lines with a **More** toggle | `details` |
| **Friends** | Who else has ngap'd it | `FriendsController.whoLiked` — see §5 |
| **CTA** | A ghost **Directions** square and the gradient **Set a date** | coordinates; `LikesController` |

The hero is **41 %** of the viewport (`kDetailHeroFraction`) with a 260 pt
floor, so the clip is the same share of a small phone and a tall one.

The page's body is a `Stack` of exactly two children — `ScreenGlow()` under the
`Column` that holds the bands. The glow is painted first and everything else
over it, which is the same order every other screen in the app uses
([Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md) §7).

## 2. The meta line

`Kampung Baru · 1.2 km · open till 2 am` — three facts joined by a middle dot,
and **every part disappears when it is unknown**:

- **Neighbourhood** — the column parsed from the caption (D91). Blank drops it.
- **Distance** — only when the device has a fix *and* the restaurant has real
  coordinates. `distanceLabelFrom` in `core/location/distance_label.dart`, with
  its trailing " away" trimmed: the line is a list of facts, not a sentence.
  No fix means the segment is gone, never "Distance loading".
- **Open state** — `OpeningHours.statusLabel`, lower-cased because it is the
  third item in a list rather than the start of one: "open till 2 am",
  "opens 5:30 pm", "closed today", "open 24 h". Unknown hours drop it.

A restaurant with none of the three shows its name and nothing under it.

## 3. The facts strip

The design shows three tiles — a price band, a rating, a typical wait. We hold
none of those three exactly, so the strip shows **only what the catalogue can
answer** and the surviving tiles widen to fill the row (D111):

| Tile | Value | Caption | Hidden when |
|---|---|---|---|
| Price | `From RM 19` | `cheapest dish` | `price_from` is null |
| Ngaps | `1,204` | `ngaps` | the count is 0, or the call failed |
| Wait | — | — | always: there is no wait data at all |

Two honest deviations from the design:

- The design's "RM 8–15 / per person" implies a measured band. What we parse
  from a caption is the **lowest dish price**, so the tile says "From RM 19 /
  cheapest dish" instead of implying a survey nobody ran.
- The design's big number is a **rating** with the ngap count as its caption.
  Our `rating` is 0 on almost every row, so the count is the big number and the
  rating is not shown at all. A tile reading "—" is a question printed where an
  answer goes.

A count that is 0 — or that failed to load — is a hidden tile, not a zero:
"0 ngaps" discourages without informing. `formatThousands` in
`facts_strip.dart` groups the figure; the app pulls in no `intl`.

## 4. Dishes

`What people bite` renders nothing at all when `dishes` is empty, which is
**most restaurants today** — the table exists and the scraper does not fill it
yet (GAP-ANALYSIS §1.3). A heading over an empty list would advertise a section
the catalogue cannot fill. Each row is a 40 px thumb, the name, the description,
and the price on the right; a dish with no price on file shows none.

## 5. Friends

`FriendsBiteRow(people: _friends.whoLiked(_id))` — a stack of faces and one
sentence, "Aiman, Mei Kee and 4 friends ngap'd this".

The page asks once, in `initState`: `FriendsController.loadWhoLiked(id)` →
the `friends_who_liked` RPC ([Friends.md](Friends.md) §6). That call is
**silent on failure** — it logs and leaves the list empty. The row is a nicety
on a screen whose job is the restaurant, and an error message about friends on
it would be louder than the thing it failed to say. There is no loading state
for the same reason: the row simply is not there until the answer arrives, and
`whoLiked` returns an empty list for a restaurant nobody has asked about yet.

Empty is the common case, and it draws **nothing at all** —
`friendsBiteCaption` returns null for an empty list and the row collapses to
`SizedBox.shrink()`. A row reading "0 friends" on a place none of your friends
have heard of would be worse than no row. The sentence is built inside the
widget from the names rather than passed in, so no call site can put a
different sentence on the same faces; the stack draws `kAvatarStackMax` (3)
faces and the caption counts them all.

### What your friends said (D147)

Under the faces sits `FriendReviews` — the stars and lines left by people whose
reviews this user may read. Same shape of rule as the row above it: empty draws
**nothing**, a failed read logs and leaves it empty, and there is no loading
state.

It needs no friendship join and no RPC. `RestaurantRepository.friendReviews`
is a plain select on `reviews`, and the table's read policy already answers who
may see a row — the caller's own and their accepted friends'. Rows with no
rating are the seeded catalogue snippets and are filtered out in the query, not
in the widget.

## 6. The two actions

**Directions** opens the platform's maps app and records the trip through
`VisitPromptController.recordDirections`, so the dashboard can later ask whether
you went. It is **hidden**, not disabled, when the restaurant has no
coordinates: 0,0 is the scraper's "unknown" and a route to Null Island is not a
route.

**Set a date** likes the place first when it is not already liked (D112), then
pushes `/plans/new` with:

```dart
{'restaurantId': …, 'title': …, 'coverUrl': first image or null,
 'neighbourhood': …, 'tag': …}
```

A like that will not write **stops the push** and says so. Arriving at the
planner having silently failed the thing the planner assumes is worse than not
arriving.

## 7. The bookmark and the bite

Two different facts sit in two different places:

- The **bite** — the notch clipped out of the hero's top-right corner — means
  *you ngap'd this*. It follows `LikesController.instance.isLiked`.
- The **bookmark** in the topbar means *it is on your wishlist*. It reads its
  filled state from `WishlistController.itemForRestaurant` and toggles through
  `addRestaurant` / `remove`, so one source answers and one source is written.

## 8. Video

The hero plays the clip **muted** (D89) behind a pill reading "Tap for sound".
It is a live control, not a caption: the same public `MutedHint` the deck card
uses, with no `IgnorePointer` over it. Tapping it posts `unMute` into TikTok's
own player and the pill reads **"Sound on"**; tapping again mutes. Nothing
reloads and the clip does not restart. D4 still holds — the message is the
interface TikTok publishes, not a script into their page (D122; see
[TikTok-Video.md](TikTok-Video.md) §2).

Opened from the deck, the hero plays **the deck's own player**, handed over in
the router's `extra` (D150) — the clip is already loaded, so the hero shows it
without the second-long black rectangle a fresh WebView costs, and the phone
holds one player instead of two. The page owns a player only when it built one
itself, which is what a deep link still does, and only then does it release it.

The hero frames the clip with `TikTokFraming.hero` — the deck card's 0.07 nudge
but **no cover**, at a flat 1.03 — where the card uses `.card` and covers its
box. The hero is barely taller than it is wide, and covering a 9:16 clip in
that box would crop it to a two-times zoom on the middle of the frame
([TikTok-Video.md](TikTok-Video.md) §4).

The page owns its player and stops it in `dispose`. It also keeps its **own
fullscreen route** (`_openPlayer`, offered from the hero when there is a clip)
— the one the deck gave up. While that route is up the hero falls back to its
photo, because one controller cannot be mounted in two WebViews.

## 9. What left the screen

The "Top review" card. With six scraped reviews across 1,607 rows it was empty
on almost every restaurant, and `SCREENS.md` puts reviews nowhere in the
redesign. What came back in its place (D147) is not that card: it is what
**your friends** said, which is empty for a different reason and a better one.
The hero thumbnail strip and the "More photos" / "Location" cards went with the
rebuild — the hero is one photo now, and the location is a distance in the meta
line plus a Directions button.

## 10. Known gaps

- **Dishes are empty** everywhere. The section is built and untested against
  real data.
- **Friends is empty on almost every row** — the graph is live, but there are
  no friendships in the catalogue's data yet, so the row draws nowhere.
- **No wait time**, and no plan to collect one.
- **Reviews are friends-only by design**, so the section is empty for anyone
  with no friends on Swipe Eat — which today is everyone. The public number
  those stars feed is the restaurant's average rating in the meta line.
- The design's **share** button is not built: there is nothing to share to yet.

## 11. Decision log

| ID | Decision | Status |
|---|---|---|
| D111 | The facts strip shows **only the facts the catalogue can answer** — the tiles it cannot fill are removed and the rest widen. The price tile is a *cheapest dish*, not the design's per-person band, and the big number is the ngap count rather than a rating that is 0 on almost every row. A count of 0, or one that failed to load, hides the tile. | locked 2026-09-06 |
| D112 | **"Set a date" likes the place first.** A plan is a thing you do about a restaurant you want, so a plan on an un-bitten place would be an orphan the Bites tab never lists. A like that will not write stops the push rather than landing the user in a planner whose premise silently failed. | locked 2026-09-06 |
