Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [Explore-Search.md](Explore-Search.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Profile-Preferences.md](Profile-Preferences.md), [Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md)

# Nearby (the map)

Tab index 1. A full-bleed map of everything inside a radius the thumb sets.

It **replaces** the cuisine grid, which answered "what kinds of food exist"
when the question a hungry person actually asks is "what is near me, and is it
open". Only a map answers that in one look. The grid, the per-cuisine page and
their controller are deleted, not hidden (D102) — see
[Explore-Search.md](Explore-Search.md), now superseded.

Files: `lib/features/nearby/` — `data/nearby_repository.dart`,
`domain/nearby_format.dart`, `models/nearby_place.dart`,
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
- **Pins** — a 76 px blob (`kSurfaceDark`, 2 px `kHairline`), or 96 px with an
  ember border for the **two closest** results. Inside: the cover photo clipped
  to the circle, a `BiteNotch` when the place is already saved (D79), an ember
  distance badge at the top right, then the name (13/w600, one line), the
  cuisine (micro, cream-70), and the open line. At most the **nearest 30** are
  drawn; the query fetches 60 so the results bar can still count the rest.
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

Unknown hours print no line at all. Roughly half the catalogue has no hours,
and "Hours unknown" on half the pins is noise, not information.

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
Settings cannot move the map under the user's thumb. Cuisine, dietary tag and
minimum-rating changes *do* refetch.

## 3. Where "near" is measured from

Resolved the way `DeckController` resolves it, in order:

1. A real device fix, through the injected resolver (D60).
2. The coordinates the profile stored (`profiles.last_latitude/longitude`),
   read by `NearbyRepository.storedOrigin()`. `(0, 0)` counts as unknown.
3. Nothing — and then the map is not drawn at all. `AppEmptyState` asks
   "Where are you eating?", offers **"Use my location"** and a secondary
   **"Not now"**. There is no stepper and no results bar in that state: there
   is nothing to centre them on.

One origin drives all three of the me-dot, the camera fit and the query, so
they can never disagree.

## 4. The `get_nearby` RPC

`public.get_nearby(p_latitude, p_longitude, p_radius_km default 3, p_limit
default 60)` — `language sql`, `stable`, `set search_path to ''`, security
invoker. Migration `get_nearby`, checked in at
`supabase/migrations/20260905120000_get_nearby.sql`.

Returns the full restaurant row plus **`distance_km`** and **`open_now`**, with
`restaurant_images` / `dishes` / `reviews` as `jsonb` aggregates so one round
trip feeds `Restaurant.fromJson` unchanged. It **returns `table(...)`, not
`setof restaurants`**, because the two extra columns are the point of the call
— and a table-returning RPC cannot be `.select()`-embedded through PostgREST,
which is why the children are aggregated in SQL instead.

It excludes inactive rows and rows at `latitude = 0 and longitude = 0`, applies
**the same profile filters `deck_scored` applies** (cuisine, dietary tags,
minimum rating), orders by `haversine_km` and caps at `p_limit` (hard ceiling
200). Missing coordinates fall back to the caller's stored profile pair, so the
function is usable with both arguments null.

`open_now` comes from `public.is_open_at`, which evaluates in
Asia/Kuala_Lumpur and returns `null` for unknown hours.

No swipe join: the map shows what is there, including places already swiped.
The deck's job is to not repeat itself; the map's job is to be complete.

RLS was checked rather than assumed — `restaurants`, `restaurant_images`,
`dishes`, `reviews`, `restaurant_cuisines` and `restaurant_dietary_tags` each
carry a `select` policy for `authenticated`, and `profiles` has `own profile
select`, so a security-invoker function reads everything it needs as the signed
-in user.

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

The bar's one action hands the whole result list to the deck (D103):
`DeckHandoff` is a tiny `ChangeNotifier` singleton in
`lib/features/restaurants/state/`. The map publishes; `DeckController.dealFrom`
deals the list **without an RPC**, and the dashboard shell brings tab 0
forward. A revision counter, not list equality, marks the change, so handing
over the same places twice still re-deals.

`dealFrom` bumps the deck's load generation, so an in-flight `load()` cannot
land on top of a hand-off, and it clears the staleness marker — these are fresh
server rows, not a cached deck (D17).

**Not done:** the deck header does not display `DeckController.handoffLabel`
("Nearby · 12 places"). The only header slot is `stalenessLabel`, which renders
in an `AppChip` with an `Icons.cloud_off_rounded` glyph; reusing it would put
an offline icon over fresh rows, and changing that widget is outside this
change's scope. The label is computed and exposed for whoever adds the slot.

## 7. Data reality

The catalogue is **Johor (844 rows) and Penang (741)**, with **474 rows
ungeocoded** — those can never carry a pin, because a wrong fix routes people
(D47) and `(0, 0)` is excluded by the RPC.

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
  stops, the counts and the cheapest price, the three origin outcomes, the
  hand-off, and that Settings' radius does not move the map.
- `test/features/nearby/nearby_tab_test.dart` — pins, the prominent pair, the
  bite, the badge, tapping through to a detail route, the stepper, the results
  bar, the empty state, the filter count, and **no overflow at 320 px** (D73).
- `test/features/restaurants/deck_handoff_test.dart` — the notifier and
  `dealFrom`, including the in-flight-load race.
- `test/features/nearby/fake_nearby_repository.dart` — `implements
  NearbyRepository` (D69), plus `FakeTileProvider` and the fixtures.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D101 | The map is `flutter_map` with a **constructor-injected** `TileProvider`; the OSM default is development only under their usage policy, and production swaps a URL template. | locked 2026-09-05 |
| D102 | The map **replaces** the cuisine grid and the per-cuisine page, which are deleted rather than kept alongside it. The DB functions behind them (`get_cuisine_counts`, `get_top_picks`) are retained. | locked 2026-09-05 |
| D103 | "Swipe all" hands the result **list** to the deck through `DeckHandoff` rather than re-querying; the deck deals what the map already fetched. | locked 2026-09-05 |
