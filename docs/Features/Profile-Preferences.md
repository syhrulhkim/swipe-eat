Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Onboarding-Taste.md](Onboarding-Taste.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [Account-Deletion-Legal.md](Account-Deletion-Legal.md)

# Profile, Preferences & Discovery Filters

> **Changed 2026-09-04.** **Passport is removed** — it appears nowhere in the
> new design, so the model, the sheet, the tile, the stat, `setPassport` and the
> three `AppUser` fields are gone (D84). The "Must try" stat went with the
> super like; "Liked" is now **Bites**.

> **Changed 2026-09-10 (D121).** The retirement was only half done: `set_passport`
> and `profiles.passport_*` stayed on the database, and `deck_scored` /
> `search_restaurants` / the Nearby client all still resolved the pin **first**.
> A pin left behind before D84 was therefore still steering a live account's
> deck. The server no longer reads the columns, `set_passport` is dropped, and
> section 4 below is history. The columns themselves are left in place —
> ignoring user data and deleting it are different decisions.

> **Changed 2026-09-05.** The tab is now the design's **S10**: a "You" title
> with a notifications bell, a portrait row, three stat tiles, and an editable
> **Your taste** list. The three static `PreferenceTile` rows (Morning mode /
> Spice bias / Nearby focus) are **gone** — they were `const` and never read the
> profile, so nothing that worked was removed. Diet & budget (`halal_only`,
> `vegetarian`, `spice_level`, `budget_min`, `budget_max`) is new and editable
> here and in Settings (D104, D105, D106).

Tab index 4. Who is signed in, what they have collected, and the rules that
shape their deck.

Files: `lib/features/profile/presentation/profile_tab.dart`,
`data/profile_repository.dart`, `data/profile_cache.dart`,
`lib/features/restaurants/presentation/discovery_filter_sheet.dart`,
`lib/core/ui/radius_options.dart`, `lib/features/settings/presentation/settings_page.dart`.

## 1. What the tab shows

Two sources, deliberately: the **profile row** (name, the default radius, the
diet & budget answers, the discovery filters and the stored fix) and the
**likes** (what they have collected). Identity and behaviour are different
reads, and the tab does not pretend one implies the other.

Below that, in the design's order:

1. **`.me-row`** — a 64 px portrait ringed in ember (initials when there is no
   photo), the name in the display face, and one small line reading
   "`last_place_name` · eating out since `<Mon YYYY>`". The place is dropped
   when there has never been a fix; a leading separator would read as a
   missing word.
2. **`.stats`** — three tiles. **bites** is the liked count from the shared
   likes cache. **plans kept** and **eating-out streak** come from a
   `ProfileStats` parameter, and are **live since 2026-09-06**: the dashboard
   fills it from `plan_stats()` via `PlansController` — see
   [Plans-Calendar.md](Plans-Calendar.md). They still read **0** rather than
   hiding when there is nothing to count, because a tile that appears later
   would change the row's shape (D106).
3. **Your taste** — Halal only, Spice (five pips, `spice_level` lit), Budget
   per person, Default radius. Each row opens a bottom sheet carrying the same
   control the first run used, writes optimistically and reverts with a
   SnackBar on failure.
4. **Playback** — one row, **Videos autoplay**: Always / On Wi-Fi only /
   Never. See below.
5. **Friends and Settings**, two ghost buttons side by side. The first reads
   `Friends · <n>` — drawn even at zero, because "Friends · 0" is the truth
   about a new account — and pushes `/friends`; the count comes from
   `FriendsController`. See [Friends.md](Friends.md).

**"Videos autoplay" is shown since D146.** It was omitted for five days
because nothing could honour it (D106): `tikTokPlayerUrl` hard-codes
`autoplay=1` and `muted=0` — which in TikTok's player means "leave the volume
control usable", not "start with sound"; the clip is silenced by posting `mute`
through the `x-tiktok-player` API on page load, and the "Tap for sound" pill
posts `unMute` (D89, D122) — and the app had no connectivity package, so
neither "Wi-Fi only" nor "Never" could be answered. `connectivity_plus` answers
it, so the setting now exists and the deck obeys it:

- **Always** (the default) — unchanged behaviour.
- **On Wi-Fi only** — `AutoplayController` watches
  `Connectivity().onConnectivityChanged` and plays only while the list carries
  `ConnectivityResult.wifi` or `.ethernet`.
- **Never** — the card shows its cover with a **"Tap to play"** pill; tapping
  mounts the player for that one card.

The setting lives in `shared_preferences` under `autoplay_setting`, not on the
profile: it is a statement about *this phone's* data plan, not about taste, so
it has no business surviving to a different device. `AutoplayController.instance`
is the app's single copy; the deck and the You tab both listen to it, and it
only notifies on a connectivity change when the setting is `wifi` — a Wi-Fi
drop must not rebuild the deck for someone who chose Always.

When autoplay is off the deck also stops **warming ahead**: `TikTokPlayerCache`
is never asked for the next card, so a card the user never taps costs no
WebView at all. See [TikTok-Video.md](TikTok-Video.md).

The tab does **not** use `DashboardTabShell`: the design puts the bell on the
same line as the title and the shell's header is a title column with nothing
beside it, so the tab reproduces the shell's chrome (background, glow, safe
area) around a two-ended topbar.

## 2. Preferences

| Field | Values | Effect |
|---|---|---|
| `morning_mode` | bool, default true | Weights toward `cuisines.is_breakfast` |
| `spice_bias` | `low` / `medium` / `high`, default `high` | Weights via `cuisines.spice_level` |
| `nearby_focus` | bool, default true | Strengthens the proximity term |
| `search_radius_km` | int, nullable | A **hard** filter, not a weight |
| `halal_only` | bool, **default false** | A **hard** filter: `restaurants.is_halal is true` |
| `vegetarian` | bool, default false | A **hard** filter: the `vegetarian` dietary tag |
| `spice_level` | smallint 1–4, nullable | The stored truth; `spice_bias` is derived from it |
| `budget_min` / `budget_max` | int, nullable | `budget_max` is a **hard** ceiling on `price_from` |

Written by `update_preferences(p_name, p_morning_mode, p_spice_bias,
p_nearby_focus, p_radius_km, p_clear_radius, p_cuisine_ids, p_dietary_ids,
p_halal_only, p_vegetarian, p_spice_level, p_budget_min, p_budget_max,
p_clear_budget)`.

### Spice: one question, one column

The design asks four steps (Mild / Medium / Pedas / Bring it) and the You tab
draws five pips. `profiles.spice_level` stores the four; `spice_bias` is
written **in step** with it by the same RPC — 1→`low`, 2→`medium`, 3 and
4→`high` — so `deck_scored`'s existing three-way term keeps scoring untouched
(D104). Null is a real value: the first-run step is skippable, so "never
answered" lights no pips and applies no weight.

### Budget: the two ends move together

"RM 10 and up" is a real answer — a floor with no ceiling — and a per-column
`coalesce` could never express it, because null already means "leave alone".
So a non-null `p_budget_min` makes the **pair** authoritative: the ceiling that
arrives with it is written as-is, null included. `p_clear_budget` is the only
route back to "Any", and it is what a skipped first-run step sends.

### Halal is off by default, and stays off

`halal_only` filters on `is_halal is true`, so an *unknown* certification does
not pass. That is deliberate — a rule the user set to avoid eating somewhere
they cannot must not be satisfied by a guess. It is also why the default is
false: 27 of the 1 605 live restaurants carry a known certification, so this is
a switch that legitimately empties the deck. The copy under it
("Hides places without halal certification") is the warning (D105).

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

**The radius is edited here too.** `DiscoveryFilterSheet` — the deck's and the
map's top-right control — carries the radius slider above the cuisine, dietary
and rating sections, because "how far may the deck look?" is the same question
as the rest of the sheet. It is still a separate write:
`applyDiscoveryFilters` writes the radius first, and only when it changed —
`ProfileRepository.updateSearchRadius`, which is `update_preferences` with
`p_radius_km` / `p_clear_radius` (there is no `update_search_radius` RPC) —
then `set_discovery_filters` second, so a failed radius write leaves the
filters untouched rather than half-applying the sheet. Settings keeps its own
slider — the same stops, the same RPC.

The sheet itself: `showDragHandle: true`, titled **`Discovery`**, with
**`Clear all`** beside the title, disabled and `kTextOnPhotoMuted` while
nothing is on. Its sections, in order, are **`Search radius`** (a discrete
slider over `kRadiusStops = [1, 2, 5, 10, 15, 20, 30, 50, 100, null]`, its
trailing slot carrying `radiusLabel` and its ends anchored `1 km` /
`Any distance`), **Cuisines** and **Dietary needs** (each trailing
`<n> chosen`, or nothing at zero rather than "0 chosen"), and the rating
chips. The apply button reads **`Apply with no limits`**, **`Apply 1 limit`**
or **`Apply <n> limits`**.

Because the sheet sets it, the radius counts towards `AppUser.activeFilterCount`
— the number on the button's badge. It counts **four kinds**: cuisines,
dietary tags, a minimum rating, and a search radius. Counting is **by kind, not
by chip**: five cuisines are one constraint, so the sheet's "Apply 2 limits" and the badge's "2"
are always the same number. The button's zero-limit label is "Apply with no
limits" rather than "show me everything", because halal, vegetarian and budget
are set in Settings and still narrow the deck (D105).

Changing any of them re-deals the deck: `DeckController` listens for
deck-shaping profile changes because the `IndexedStack` never re-inits the tabs,
and stale cards would break the promise the filter just made.

| Filter | Usable today? |
|---|---|
| Cuisine ids | Yes — 23 cuisines, all 1,607 rows mapped |
| Dietary tag ids | Yes — 6 tags |
| Minimum rating | **No.** 2 of 1,607 rows have a rating; any threshold empties the deck |

The sheet says that last row out loud: pick any rating limit and a caution
appears under the chips reading `Barely any place here is rated yet — a rating
limit will empty the deck.` The filter is left in place rather than removed —
the data is what is missing, not the feature — but a user who empties their
own deck should be told why before they conclude the app is broken.

`filter_min_rating` is built and correct, and unusable until the ratings gap is
fixed. See [Restaurant-Data.md](Restaurant-Data.md).

**Note the contrast with the Liked tab's filter sheet**, which is client-side
and does not refetch. That list is finite and already owned, so filtering it is
a view concern (D24).

## 4. ~~Passport~~ — retired 2026-09-04 (D84), unwired 2026-09-10 (D121)

> History. `set_passport` is dropped and nothing reads
> `profiles.passport_latitude/longitude` any more. The origin chain in both
> `deck_scored` and `search_restaurants` is now `p_latitude, else the stored
> fix` — the same two steps the client measures its card distances from.

~~Deal a different city's deck without being there.~~ `set_passport(p_latitude,
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

**The name follows the fix.** Since
`supabase/migrations/20260910100000_update_location_name_follows_fix.sql` the
write is `last_place_name = nullif(btrim(p_place_name), '')` — no `coalesce`
back to the old value — and `ProfileRepository.updateLocation` always sends
`p_place_name`, null included. A reverse geocode that comes back empty
therefore clears the name rather than leaving the previous town standing over
new coordinates. The deck header falls back to **`Nearby`** when there is no
name, and says **`Location off`** when the position it has is a fallback
rather than a fix.

`AppUser.lastLatitude` / `lastLongitude` are read through
`AuthRepository._profileColumns` on every profile load, so the deck, the card's
distance label and the Nearby map all measure from one origin (D121).

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
offline launch knows the user's name, default radius, diet & budget answers and
discovery filters rather than rendering a blank tab. Every profile write RPC returns the whole `profiles` row, so the
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
- **Per-session filters** that do not persist. Filters are profile state by
  design (D33).

## 10. Decision log

| ID | Decision | Status |
|---|---|---|
| D11 | Profile write RPCs return the whole `profiles` row; the client never follows up with a read. | locked 2026-08-23 |
| D12 | ~~Passport resolves server-side in `deck_scored`, so the client's per-load GPS fix cannot override it.~~ | **superseded by D121 2026-09-10** |
| D24 | Deck filters are server-side profile state; the Liked tab's filter sheet is client-side. | locked 2026-08-31 |
| D33 | Discovery filters and radius live on `profiles`, not device storage, so they survive a reinstall. | locked 2026-08-31 |
| D34 | Filters are applied in `deck_scored`'s `candidates` CTE so they bind the exhaustion fallback too, not just the fresh-cards query. | locked 2026-08-31 |
| D35 | `update_preferences` takes an explicit `p_clear_radius`, because null already means "leave unchanged". | locked 2026-08-23 |
| D36 | The three taste switches are weights; radius and dietary tags are hard filters. | locked 2026-08-23 |
| D104 | `spice_level` 1–4 is the stored truth; `spice_bias` is derived from it on every write. Resolves GAP-ANALYSIS §4.1. | locked 2026-09-05 |
| D105 | `halal_only`, `vegetarian` and `budget_max` are hard deck filters. Halal needs `is_halal is true` (unknown does not pass), which is why it defaults off; an unknown `price_from` **does** pass the budget ceiling. | locked 2026-09-05 |
| D121 | D84's passport retirement is finished on the database: `deck_scored` and `search_restaurants` stop reading `profiles.passport_*`, and `set_passport` is dropped. One origin chain — the caller's fix, else the profile's stored one — shared by the deck, Explore, the Nearby map and the card's own distance label. The columns stay: ignoring data and deleting it are separate decisions. | locked 2026-09-10 |
| D122 | "Tap for sound" drives TikTok's player through their documented `x-tiktok-player` postMessage API (`mute` / `unMute`), not through the URL. The player URL is now always `muted=0`; a clip still starts silent (D89) because the handle posts `mute` on `onPageFinished`. | locked 2026-09-10 |
| D106 | The You tab's stats read 0 for what nothing feeds yet rather than hiding a tile, its taste rows edit in place through sheets, and "Videos autoplay" is omitted because nothing could honour it. | locked 2026-09-05, autoplay clause superseded by D146 |
| D146 | "Videos autoplay" (Always / Wi-Fi only / Never) ships, backed by `connectivity_plus`. It is device state in `shared_preferences`, not profile state, and turning it off also stops the deck warming the next card ahead. | locked 2026-09-11 |
