Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Onboarding-Taste.md](Onboarding-Taste.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Account-Deletion-Legal.md](Account-Deletion-Legal.md)

# Profile, Preferences, Filters & Passport

> **Changed 2026-09-04.** **Passport is removed** — it appears nowhere in the
> new design, so the model, the sheet, the tile, the stat, `setPassport` and the
> three `AppUser` fields are gone (D84). `set_passport` and
> `profiles.passport_*` remain on the database, unused. The "Must try" stat went
> with the super like; "Liked" is now **Bites**.

Tab index 4. Who is signed in, what they have collected, and the switches that
shape their deck.

Files: `lib/features/profile/presentation/profile_tab.dart`,
`data/profile_repository.dart`, `data/profile_cache.dart`,
`models/passport_destination.dart`,
`lib/features/restaurants/presentation/discovery_filter_sheet.dart`,
`lib/core/ui/radius_options.dart`, `lib/features/settings/presentation/settings_page.dart`.

## 1. What the tab shows

Two sources, deliberately: the **profile row** (name, passport, radius) and the
**likes** (what they have collected). Identity and behaviour are different
reads, and the tab does not pretend one implies the other.

Below that: the three taste switches, the radius picker, discovery filters,
Passport, and the route to Settings.

## 2. Preferences

| Field | Values | Effect |
|---|---|---|
| `morning_mode` | bool, default true | Weights toward `cuisines.is_breakfast` |
| `spice_bias` | `low` / `medium` / `high`, default `high` | Weights via `cuisines.spice_level` |
| `nearby_focus` | bool, default true | Strengthens the proximity term |
| `search_radius_km` | int, nullable | A **hard** filter, not a weight |

Written by `update_preferences(p_name, p_morning_mode, p_spice_bias,
p_nearby_focus, p_radius_km, p_clear_radius, p_cuisine_ids, p_dietary_ids)`.

That function needs an explicit **`p_clear_radius`** because null already means
"don't change this field" in every other parameter. Without it there would be
no way to express "remove the radius entirely" — a real state, meaning *deal me
anything*.

The three switches are weights; the radius is a filter. Confusing the two is
the easiest mistake here: a weight can be overcome by a strong enough signal
elsewhere, a filter cannot.

## 3. Discovery filters

Server-side profile state, set by `set_discovery_filters(p_cuisine_ids,
p_dietary_tag_ids, p_min_rating) → profiles` and applied inside
`deck_scored`'s `candidates` CTE — so they constrain **both** the fresh-cards
query and the exhaustion fallback. Bolting them onto one branch of `get_deck`
would let the fallback serve cards the filter had just excluded.

They live on `profiles` rather than in device storage so they **survive a
reinstall**, the same way `search_radius_km` already does.

Changing any of them re-deals the deck: `DeckController` listens for
deck-shaping profile changes because the `IndexedStack` never re-inits the tabs,
and stale cards would break the promise the filter just made.

| Filter | Usable today? |
|---|---|
| Cuisine ids | Yes — 23 cuisines, all 1,607 rows mapped |
| Dietary tag ids | Yes — 6 tags |
| Minimum rating | **No.** 2 of 1,607 rows have a rating; any threshold empties the deck |

`filter_min_rating` is built and correct, and unusable until the ratings gap is
fixed. See [Restaurant-Data.md](Restaurant-Data.md).

**Note the contrast with the Liked tab's filter sheet**, which is client-side
and does not refetch. That list is finite and already owned, so filtering it is
a view concern (D24).

## 4. Passport

Deal a different city's deck without being there. `set_passport(p_latitude,
p_longitude, p_place_name) → profiles`; a null latitude means off.

Resolution happens **server-side** in `deck_scored`:

```sql
coalesce(
  (select m.passport_latitude from me m),  -- manual pin beats everything
  p_latitude,                              -- the device's real fix
  (select m.last_latitude from me m)       -- last known
) as lat
```

This is the whole point of doing it in SQL: `DeckController.load()` passes a
GPS fix on every call, so a client-side implementation would silently override
an active Passport every time the deck reloaded (D12).

The deck header chip follows the same precedence — while a pin is set it shows
the **passport** place name, never the user's real town, because the deck is
dealing that city and the chip must not claim otherwise.

UI details: a modal sheet returning `PassportDestination?`, a `_savingPassport`
flag so the row shows "Saving…" and refuses double taps, a snackbar confirming
either the new pin or "Passport off — back to your real location", and a
distinct snackbar on failure. Clearing an already-off passport short-circuits
rather than writing.

## 5. Location

`update_location(p_latitude, p_longitude, p_place_name, p_source) → profiles`
keeps `last_latitude`, `last_longitude`, `last_place_name`, `located_at` and
`location_source` current.

The stored fix is what lets a user who **denied or revoked** location still get
a sensible deck — `deck_scored` falls back to it. `location_source` records how
the fix was obtained (including `'denied'`, written by onboarding), so ranking
knows whether to keep waiting for one.

Reverse geocoding to a place name is `lib/core/location/place_name.dart`;
distance formatting is `distance_label.dart`; opening the maps app is
`open_directions.dart`, which is also what arms the visit prompt
([Likes-Visits.md](Likes-Visits.md)).

## 6. Caching

`profile_cache.dart` persists the profile in `shared_preferences`, so a cold
offline launch knows the user's name, radius and passport rather than rendering
a blank tab. Every profile write RPC returns the whole `profiles` row, so the
cache is refreshed from the write's own response and never needs a follow-up
read (D11).

## 7. Settings

`settings_page.dart` holds the destructive and legal surface rather than the
preference surface:

- Sign out.
- **Delete account** — `AuthController.deleteAccount()` via the
  `delete-account` edge function, with a `_deleting` flag guarding the UI.
- Links to the privacy policy, terms, and deletion instructions, opened with
  `url_launcher` against the `legal` edge function's URLs.

Both stores require the deletion path; see
[Account-Deletion-Legal.md](Account-Deletion-Legal.md).

## 8. Known gaps

- **`filter_min_rating` is unusable** — see above.
- **`profiles.role` is unused.** The column exists; nothing reads or writes it.
  There is no roles concept in the product.
- **`avatar_url` is unused** by the app — Apple/Google may populate it, but no
  surface renders an avatar.
- No way to change email or password from Settings.

## 9. Out of scope

- **Roles and permissions.** `profiles.role` is dead weight, not a hook to
  build on.
- **Multiple saved passport destinations** — one pin at a time.
- **Per-session filters** that do not persist. Filters are profile state by
  design (D33).

## 10. Decision log

| ID | Decision | Status |
|---|---|---|
| D11 | Profile write RPCs return the whole `profiles` row; the client never follows up with a read. | locked 2026-08-23 |
| D12 | Passport resolves server-side in `deck_scored`, so the client's per-load GPS fix cannot override it. | locked 2026-08-31 |
| D24 | Deck filters are server-side profile state; the Liked tab's filter sheet is client-side. | locked 2026-08-31 |
| D33 | Discovery filters and radius live on `profiles`, not device storage, so they survive a reinstall. | locked 2026-08-31 |
| D34 | Filters are applied in `deck_scored`'s `candidates` CTE so they bind the exhaustion fallback too, not just the fresh-cards query. | locked 2026-08-31 |
| D35 | `update_preferences` takes an explicit `p_clear_radius`, because null already means "leave unchanged". | locked 2026-08-23 |
| D36 | The three taste switches are weights; radius and dietary tags are hard filters. | locked 2026-08-23 |
