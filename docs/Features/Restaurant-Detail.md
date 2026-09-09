Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-06
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
| **Hero** | The clip, or the first photo, or the TikTok placeholder. Two scrims, the muted hint, back + wishlist buttons, and low over the deep end the tags, the 36 px name and one meta line | `videoUrl`, `imageUrls`, `tag`, `isHalal`, `neighbourhood`, `hours`, the device fix |
| **Facts** | Two tiles at most: the cheapest dish, and the ngap count | `priceFrom`, `RestaurantRepository.ngapCount` |
| **What people bite** | The dishes, each with a thumb, a name, a description and a price | `dishes` |
| **About** | The scraped caption, three lines with a **More** toggle | `details` |
| **Friends** | Who else has ngap'd it | nothing yet — see §5 |
| **CTA** | A ghost **Directions** square and the gradient **Set a date** | coordinates; `LikesController` |

The hero is **41 %** of the viewport (`kDetailHeroFraction`) with a 260 pt
floor, so the clip is the same share of a small phone and a tall one.

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

`FriendsBiteRow` is built and wired into the page with an empty avatar list and
no caption, and renders **zero height** in that state. It is the shape the
friends phase fills; until the social graph exists the screen does not claim
anybody has been.

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

The hero plays the clip **muted** (D89) and the hint says "Tap for sound", not
the prototype's "tap to unmute": a tap opens the fullscreen player, which is
where TikTok's own volume control lives, and D4 forbids driving their player
ourselves. The page owns its player and stops it in `dispose`; while the
fullscreen route is up the hero falls back to its photo, because one controller
cannot be mounted in two WebViews.

## 9. What left the screen

Reviews. With six reviews across 1,607 rows the "Top review" card was empty on
almost every restaurant, and `SCREENS.md` puts reviews nowhere in the redesign.
The hero thumbnail strip and the "More photos" / "Location" cards went with the
rebuild — the hero is one photo now, and the location is a distance in the meta
line plus a Directions button.

## 10. Known gaps

- **Dishes are empty** everywhere. The section is built and untested against
  real data.
- **Friends is empty** until phase 8.
- **No wait time**, and no plan to collect one.
- The **muted hint** is duplicated from `swipe_card.dart`, whose copy is
  private to that file. If a third surface needs it, it belongs in
  `core/ui/`.
- The design's **share** button is not built: there is nothing to share to yet.

## 11. Decision log

| ID | Decision | Status |
|---|---|---|
| D111 | The facts strip shows **only the facts the catalogue can answer** — the tiles it cannot fill are removed and the rest widen. The price tile is a *cheapest dish*, not the design's per-person band, and the big number is the ngap count rather than a rating that is 0 on almost every row. A count of 0, or one that failed to load, hides the tile. | locked 2026-09-06 |
| D112 | **"Set a date" likes the place first.** A plan is a thing you do about a restaurant you want, so a plan on an un-bitten place would be an orphan the Bites tab never lists. A like that will not write stops the push rather than landing the user in a planner whose premise silently failed. | locked 2026-09-06 |
