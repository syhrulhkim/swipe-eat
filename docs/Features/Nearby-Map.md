Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-06
Cross-references: [Explore-Search.md](Explore-Search.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Profile-Preferences.md](Profile-Preferences.md), [Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md)

# Nearby (the map)

Tab index 1. A full-bleed map of everything inside a radius the thumb sets.

It **replaces** the cuisine grid, which answered "what kinds of food exist"
when the question a hungry person actually asks is "what is near me, and is it
open". Only a map answers that in one look. The grid, the per-cuisine page and
their controller are deleted, not hidden (D102) — see
[Explore-Search.md](Explore-Search.md), now superseded.

Files: `lib/features/nearby/` — `data/nearby_repository.dart`,
`domain/nearby_format.dart`, `domain/pin_spread.dart`, `models/nearby_place.dart`,
`state/nearby_controller.dart`, and `presentation/` (`nearby_tab.dart`,
`nearby_pin.dart`, `nearby_radius_stepper.dart`, `nearby_results_bar.dart`).

## 1. Layout

Everything floats over the tiles; the map itself is edge to edge, under the
status bar and behind the nav.

- **Topbar** — a single **Filters** icon button, right-aligned, carrying the
  active-filter count as a dot. There is **no Back button**: this is a tab, not
  a pushed screen. The button opens the deck's own `showDiscoveryFilterSheet`,
  so one sheet serves both surfaces.
- **Me-dot** — an 18 px ember circle with a 4 px `kBackgroundDark` border and a
  12 px lava-at-22% halo (`kNearbyMeHalo`), drawn at the resolved origin.
- **Pins** — a blob (`kSurfaceDark`, 2 px `kHairline`) whose size says how
  far the place is: 96 px (`kNearbyPinBigSize`) at the origin, shrinking
  linearly to 52 px (`kNearbyPinSmallSize`) at the edge of the radius, so the
  map reads at a glance without a single number. The **two closest** also get
  an ember border. Inside: the cover photo clipped to the circle, a
  `BiteNotch` when the place is already saved (D79), an ember distance badge
  at the top right, then the name (13/w600, one line), the cuisine (micro,
  cream-70), and the open line. Only the **nearest 5** are drawn (D116); the
  query fetches 60 so the results bar can still count the rest and "Swipe all"
  can deal them. The camera **fits those five** plus the me-dot rather than the
  whole circle, so five places 400 m away fill the screen instead of huddling
  under one another in the middle.
- **No two pins overlap.** After each camera change the tab projects the pins
  to screen space and runs `spreadPins` (`domain/pin_spread.dart`): the nearest
  pin stays on its true position, every later pin is nudged along whichever
  axis needs the smaller move until every box (blob + caption) clears every
  other by `kNearbyPinGap` (4 px). The nudge is a marker offset, not a change
  to the place's coordinate, and the pure function is unit-tested on its own.
- **Radius stepper**, bottom right — minus, the value block ("Away from you"
  over a 30/w800 number with a 14/w600 unit), plus.
- **Results bar**, flush with the nav, rounded at the top only — "From RM *n*"
  (hidden when nothing names a price), "Open now *n*", and the ember
  **"Swipe all *n*"** button.
- **A scrim** (`kNearbyMapScrim`) sits between the tiles and the markers. OSM's
  raster tiles are a daylight map; without it the cream text on the pins has
  nothing to sit against.

Tapping a pin pushes `/restaurant/:id` with the detail payload, exactly as the
deck and the Bites grid do (D57).

### The open line

Read from the row's hours in the device's clock, never from a server flag alone:

| Case | Line | Tone |
|---|---|---|
| Open, closes ≥ 60 min from now | `Open` | fresh |
| Open around the clock | `Open · 24 h` | fresh |
| Open, closing within 60 min | `Closes 10 pm` | muted |
| Closed, opens later today | `Opens 5:30 pm` | muted |
| Closed for the rest of today | `Closed today` | muted |
| Hours unknown | *nothing* | — |

Unknown hours print no line at all — and that is the common case: **1,424 of
the 1,605 active rows carry no `opens_at`** (2026-09-05). "Hours unknown" on
nine pins in ten is noise, not information.

`open_now` from the server is used for one thing only: the **"Open now *n*"**
count in the results bar. It counts `true`, so `null` (unknown) is not counted
— the bar says how many *are* open, not how many *might be*.

## 2. The radius

Steps are `0.5, 1, 2, 3, 5, 8, 12, 20` km. The stepper walks them; there is no
free slider, because a map that can be dragged to 7.4 km invites fiddling
rather than deciding.

The initial radius is the profile's `search_radius_km` **snapped to the nearest
step**, or 3 km when the profile names none. A tie rounds **down** — 10 km
lands on 8, not 12. The radius is a promise about how far the user is willing
to go, and rounding it up would put places outside that promise on the map.

Changing the radius refetches and re-fits the camera. It **never writes the
profile**: the map's circle is a look, and Settings' radius is a standing
preference for the deck. For the same reason `NearbyController` deliberately
leaves `searchRadiusKm` out of the filter signature it watches, so a change in
Settings cannot move the map under the user's thumb.

One exception, and it is about a race rather than about Settings: the tab can be
built **before the profile has hydrated**, in which case the map opened on the
default 3 km rather than on the user's radius. The controller tracks whether the
stepper has been touched, and until it has, a profile arriving late is allowed
to move the circle to its own radius. After the first tap the circle is the
user's answer and nothing overrules it — including a tap that changed nothing.

Cuisine, dietary tag and minimum-rating changes *do* refetch, and so do the
three diet & budget answers, because `get_nearby` now applies them as hard rules
(D105).

## 3. Where "near" is measured from

Resolved the way `deck_scored` resolves it, in order:

1. The **passport pin** (`profiles.passport_latitude/longitude`) — a pin the
   user dropped on purpose beats a fix they never chose (D12).
2. A real device fix, through the injected resolver (D60).
3. The coordinates the profile stored (`profiles.last_latitude/longitude`).
   `(0, 0)` counts as unknown, for the passport and the stored pair alike.
   Both pairs come back from one read, `NearbyRepository.profileOrigins()`,
   because the passport has to be known *before* the device is asked. A read
   that fails is not an error the map shows: the device fix is still worth
   trying, and with no fix either the empty state already says the right thing.
4. Nothing — and then the map is not drawn at all. `AppEmptyState` asks
   "Where are you eating?", offers **"Use my location"** and a secondary
   **"Not now"**. There is no stepper and no results bar in that state: there
   is nothing to centre them on.

One origin drives all three of the me-dot, the camera fit and the query, so
they can never disagree. That is also **why the passport is resolved on the
client** rather than inside `get_nearby` the way `deck_scored` does it: an RPC
that quietly swapped in a different origin would measure every `distance_km`
from a place the map is not showing, and the me-dot would sit somewhere else
again.

## 4. The `get_nearby` RPC

`public.get_nearby(p_latitude, p_longitude, p_radius_km default 3, p_limit
default 60)` — `language sql`, `stable`, `set search_path to ''`, security
invoker. First checked in at
`supabase/migrations/20260905120000_get_nearby.sql`, then **dropped and
recreated** by
`supabase/migrations/20260906140000_get_nearby_diet_budget_swiped.sql`, which is
what the app calls today. The argument list is unchanged; only the return type
grew, which is why a drop was needed rather than a replace.

Returns the full restaurant row plus **`distance_km`**, **`open_now`** and
**`swiped`**, with
`restaurant_images` / `dishes` / `reviews` as `jsonb` aggregates so one round
trip feeds `Restaurant.fromJson` unchanged. It **returns `table(...)`, not
`setof restaurants`**, because the two extra columns are the point of the call
— and a table-returning RPC cannot be `.select()`-embedded through PostgREST,
which is why the children are aggregated in SQL instead.

It excludes inactive rows and rows at `latitude = 0 and longitude = 0`, applies
**every rule `deck_scored` applies** — cuisine, dietary tags, minimum rating,
and the three hard `halal_only` / `vegetarian` / `budget_max` predicates copied
from it verbatim (D105) — orders by `haversine_km` and caps at `p_limit` (hard
ceiling 200). Missing coordinates fall back to the caller's stored profile pair,
so the function is usable with both arguments null. It does **not** read the
passport pin: that is the client's job here, for the reason in section 3.

The three hard rules keep their `deck_scored` shapes exactly, because the same
reasoning holds on a map: `halal_only` needs `is_halal is true` (unknown is not
good enough for a rule the user set to avoid eating somewhere they cannot); the
vegetarian tag is matched on `dietary_tags.slug` so it survives a reseed; and an
unknown `price_from` **passes** the budget ceiling, because most rows have no
price and dropping them would empty the map.

`open_now` comes from `public.is_open_at`, which evaluates in
Asia/Kuala_Lumpur and returns `null` for unknown hours.

**`swiped`** is an `exists` against the caller's own `swipes` rows. It is not a
filter: the map still draws a swiped place, because the map's job is to say what
is *there*. It is only what "Swipe all" leaves out (D117).

Because `swiped` needs `auth.uid()`, the grant to `anon` is gone: the function
is executable by `authenticated` and `service_role` only.

RLS was checked rather than assumed — `restaurants`, `restaurant_images`,
`dishes`, `reviews`, `restaurant_cuisines` and `restaurant_dietary_tags` each
carry a `select` policy for `authenticated`, `swipes` carries the owner-only
`own swipes` policy, and `profiles` has `own profile select`, so a
security-invoker function reads everything it needs as the signed-in user — and
the `swiped` subquery can only ever see the caller's own rows.

## 5. Tiles

`flutter_map` + `latlong2`, with the `TileProvider` **constructor-injected**
(D101, D60). The default is OpenStreetMap's public tile server with
`userAgentPackageName` set to the real application id, and the page carries the
required "© OpenStreetMap" attribution.

**OSM's public tiles are development only.** Their usage policy forbids a
released app pointing at them. Shipping means swapping the URL template for a
paid or self-hosted source; nothing else in the tab changes, and the injection
point is already there. Tests pass a `FakeTileProvider` that returns a
transparent image, so the suite never touches the network.

## 6. "Swipe all *n*"

The bar's one action hands the result list to the deck (D103) — minus anything
the user has already swiped (D117). The pins keep showing all of it; the button
counts and deals only the unswiped, so a circle the user has worked through
still shows its pins, under a disabled **"Swipe all 0"**, rather than re-dealing
cards the deck has already been through.

`DeckHandoff` is a tiny `ChangeNotifier` singleton in
`lib/features/restaurants/state/`. The map publishes; `DeckController.dealFrom`
deals the list **without an RPC**, and the dashboard shell brings tab 0
forward. A revision counter, not list equality, marks the change, so handing
over the same places twice still re-deals.

`dealFrom` bumps the deck's load generation, so an in-flight `load()` cannot
land on top of a hand-off, and it clears the staleness marker — these are fresh
server rows, not a cached deck (D17). The label is cleared again by **both**
outcomes of the next `load()`, the offline-cache fallback included: cards read
off the device days ago must not be credited to "Nearby · 6 places".

`DashboardPage` threads its `handoff` down to `SwipeDeck` and `NearbyTab` as
well as listening to it itself, so one injected instance wires all three ends of
the journey — publisher, dealer, and the shell that brings tab 0 forward.

**Not done:** the deck header does not display `DeckController.handoffLabel`
("Nearby · 12 places"). The only header slot is `stalenessLabel`, which renders
in an `AppChip` with an `Icons.cloud_off_rounded` glyph; reusing it would put
an offline icon over fresh rows, and changing that widget is outside this
change's scope. The label is computed and exposed for whoever adds the slot.

## 7. Data reality

The catalogue is **Johor (844 rows) and Penang (741)**, with **474 rows
ungeocoded** — those can never carry a pin, because a wrong fix routes people
(D47) and `(0, 0)` is excluded by the RPC.

`NearbyPlace.openNow` — the server's `open_now` — is **not what a pin reads**:
the pin recomputes its line from the row's hours against
`OpeningHours.kualaLumpurNow`, so the two can only ever agree, and `open_now`
feeds the results bar's "Open now *n*" and nothing else.

A user in **Kuala Lumpur therefore sees an empty map** — correctly: there is
nothing of ours near them yet. It resolves when the catalogue is scraped for KL
(phase 9 of the gap analysis), not in this code. **Nothing here hardcodes a
city**; the origin is always the user's, and the empty state says "Nothing
within 3.0 km. Widen the circle." rather than naming a place.

## 8. Tests

No network and no platform channels anywhere: the tile provider, the position
resolver, the clock and the repository are all injected.

- `test/features/nearby/nearby_format_test.dart` — the radius snapping, the
  distance strings, every branch of the open line.
- `test/features/nearby/nearby_controller_test.dart` — radius walking and its
  stops, the counts and the cheapest price, the four origin outcomes including
  **the passport pin beating a real device fix**, the hand-off and its
  **skipping of swiped places**, that Settings' radius does not move a circle
  the thumb has set but *does* move one it has not, that a diet or budget answer
  refetches, that the default clock is **Kuala Lumpur time**, and that a load in
  flight when the controller is disposed goes quiet instead of throwing.
- `test/features/nearby/pin_spread_test.dart` — the spreader: untouched when
  apart, pushed apart when piled, the first pin never moves, the cheaper axis.
- `test/features/nearby/nearby_tab_test.dart` — pins, the prominent pair,
  distance-scaled sizes, two places on one spot drawn apart, the
  bite, the badge, tapping through to a detail route, the stepper, the results
  bar, the empty state, the filter count, **no overflow at 320 px**, and **a pin
  that keeps its marker box at `TextScaler.linear(2.0)`** (D73).
- `test/features/restaurants/deck_handoff_test.dart` — the notifier and
  `dealFrom`, including the in-flight-load race, that the **offline-cache
  fallback drops the hand-off label** with the cards it replaces, and that each
  of the three diet & budget answers re-deals the deck.
- `test/features/nearby/fake_nearby_repository.dart` — `implements
  NearbyRepository` (D69), plus `FakeTileProvider` and the fixtures.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D101 | The map is `flutter_map` with a **constructor-injected** `TileProvider`; the OSM default is development only under their usage policy, and production swaps a URL template. | locked 2026-09-05 |
| D102 | The map **replaces** the cuisine grid and the per-cuisine page, which are deleted rather than kept alongside it. The DB functions behind them (`get_cuisine_counts`, `get_top_picks`) are retained. | locked 2026-09-05 |
| D103 | "Swipe all" hands the result **list** to the deck through `DeckHandoff` rather than re-querying; the deck deals what the map already fetched. | locked 2026-09-05 |
| D116 | The map draws the **nearest five** places, sized by distance (96 px at the origin to 52 px at the radius edge), spread apart in screen space so no two overlap, with the camera fitted to those five. Five is what a thumb can pick between; the results bar and "Swipe all" still speak for the full fetch. | locked 2026-09-06 |
| D117 | "Swipe all" deals only the places the caller has **not already swiped**; the pins still show all of them. `get_nearby` answers `swiped` per row, and the button counts and hands over the rest. Saying what is there is the map's job; not repeating itself is the deck's, and a hand-off of cards the deck has already shown reads as the app forgetting. | locked 2026-09-06 |
