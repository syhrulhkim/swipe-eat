Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Profile-Preferences.md](Profile-Preferences.md)

# Explore & Search

Tab index 1. The catalogue arranged **by craving rather than by distance** — the
deliberate counterpart to the deck, which is ordered by proximity and ranking.

Files: `lib/features/dashboard/presentation/explore_tab.dart`,
`cuisine_restaurants_page.dart`, `state/explore_controller.dart`,
`lib/features/restaurants/presentation/restaurant_grid_card.dart`.

## 1. Layout

Top to bottom:

1. **Top Picks rail** — today's shortlist, only when non-empty.
2. **Cuisine grid** — one tile per active cuisine, biggest categories first.

A tile opens `/explore/cuisine/:id`, a per-cuisine list where the radius rule
applies.

### The cuisine grid

Backed by `get_cuisine_counts()`, which returns `cuisine_id, slug, label,
emoji, restaurant_count, cover_url` **ordered by count descending
server-side** — the client must not re-sort. 23 cuisines today, covering all
1,607 restaurants.

Each tile is the cuisine's best cover photo under a scrim, with the emoji and
label on top and the count as a small line beneath.

### The Top Picks rail

`get_top_picks(p_limit)` — `get_deck`'s first query with a small limit and no
exhaustion fallback, so it is the head of the same ranking. Unswiped rows only,
which means it **thins out as the user swipes** and disappears entirely when
empty.

No coordinates are passed: the RPC resolves passport, then the stored fix,
server-side. The server caps the limit at 20; the client asks for 10.

Because `deck_scored`'s seed is the current date in `Asia/Kuala_Lumpur`, the
shortlist is stable for a day and reshuffles at midnight for free.

The rail is **best-effort**: on failure it is left empty and simply does not
render. The grid is the tab's contract; the rail is a bonus, and a failed
shortlist should not take the tab down with it.

## 2. Search

`search_restaurants(p_query, p_limit, p_latitude, p_longitude, p_radius_km,
p_cuisine_id) → setof restaurants`.

- A **null query browses** the catalogue; a present one runs full-text search
  against `restaurants.search`, a generated `tsvector` over
  `name ‖ tag ‖ details` with a GIN index. Configuration is `'simple'`, not
  `'english'` — Malay and English restaurant names do not want English
  stemming.
- `p_cuisine_id` narrows to one cuisine. This is how a tap on an Explore tile
  becomes a list: the same RPC, one argument different.
- **The same radius rule as the deck applies.** What the user cannot be served,
  they cannot find. This is intentional, not an oversight: a search result the
  deck refuses to deal is a dead end.
- The RPC **caps at 100 rows**. With no radius set, a large catalogue does not
  fit — the closest 100 win, which is the right 100 for a browse surface.

## 3. Known gaps

- **474 restaurants are unreachable through Explore.** They sit at `(0, 0)`, so
  the radius rule and the distance ordering both exclude them. Unlike the deck
  — where `DeckRanker` grants unlocated rows neutral half-credit — search has
  no such kindness. This is the single biggest functional cost of the
  geocoding gap.
- **No sort control.** Results come back in the RPC's order; the user cannot
  ask for rating or distance explicitly. Rating would be meaningless anyway
  (2 of 1,607 rows have one).
- **No text search on cuisine or dietary labels** — the `tsvector` covers
  `name`, `tag` and `details` only, so "halal" finds only rows that say so in
  their own text.
- The 100-row cap is silent; there is no "refine your search" affordance when
  it truncates.

## 4. Out of scope

- **A map view.** `kSurfaceDeepest` exists as "the background behind the
  explore map", but no map is built. 474 unlocated rows would make it look
  broken.
- **Price and opening-hours filters** — no columns, no source.
- **Saved searches / search history.**

## 5. Decision log

| ID | Decision | Status |
|---|---|---|
| D19 | Explore applies the same radius rule as the deck — findable and servable are the same set. | locked 2026-08-23 |
| D20 | `search_restaurants` caps at 100 and lets the closest win, rather than paginating a browse surface. | locked 2026-08-23 |
| D21 | The `tsvector` uses the `'simple'` configuration, not `'english'` — the catalogue is Malay and English. | locked 2026-08-22 |
| D22 | The Top Picks rail is best-effort; its failure must not fail the tab. | locked 2026-08-31 |
| D23 | Cuisine tiles are ordered server-side by count; the client must not re-sort. | locked 2026-08-31 |
