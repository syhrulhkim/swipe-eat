Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md), [General/PLAN.md](../General/PLAN.md), [General/RUNBOOK.md](../General/RUNBOOK.md), [Tests/CONVENTIONS.md](../Tests/CONVENTIONS.md)

# Frontend Stack & Conventions

Flutter **3.47.1**, Dart, targeting iOS and Android. App version `1.0.0+1`.

## 1. Dependencies

Every one of these is load-bearing; there is no dependency here that a single
call site could replace.

| Package | Version | Why |
|---|---|---|
| `supabase_flutter` | ^2.17.2 | Auth, PostgREST, Storage. Persists and refreshes the session itself |
| `go_router` | ^17.3.0 | Routing, with `refreshListenable` wired to `AuthController` |
| `forui` | ^0.22.3 | Component primitives under the custom design system |
| `webview_flutter` | ^4.13.0 | The TikTok player |
| `webview_flutter_android` | ^4.14.0 | Direct dependency — the player needs gesture/inline-playback settings the facade does not expose |
| `webview_flutter_wkwebview` | ^3.26.0 | Same, for iOS |
| `geolocator` | ^14.0.2 | The device fix |
| `geocoding` | ^5.0.0 | Reverse-geocoding a fix to a place name |
| `flutter_map` | ^8.3.2 | The Nearby map's **camera only** — it projects a coordinate onto the screen. No tiles are drawn (D126) |
| `latlong2` | ^0.10.1 | `flutter_map`'s coordinate type |
| `google_sign_in` | ^7.2.0 | Native Google sheet → `signInWithIdToken` |
| `sign_in_with_apple` | ^8.1.0 | Native Apple sheet |
| `crypto` | ^3.0.6 | Hashes the Apple sign-in nonce |
| `shared_preferences` | ^2.5.5 | The offline caches (deck, profile, visit prompts) |
| `url_launcher` | ^6.3.1 | Hands a maps/navigation URL to the OS; opens the legal pages |
| `share_plus` | ^13.3.0 | Hands the wishlist to the OS share sheet as plain text |
| `connectivity_plus` | ^6.1.0 | Tells the autoplay setting whether this is Wi-Fi or somebody's data plan (D146). Reached only through an injected `Stream<bool>`, so no test touches the channel |
| `flutter_contacts` | ^2.3.1 | Reads phone numbers off the address book for the onboarding friends step. Numbers are normalised and hashed before they leave the device; reached only through an injected typedef, so no test touches the channel |
| `lottie` | ^3.3.2 | The small bundled vector loops |
| `sentry_flutter` | ^9.28.0 | Crash reporting, off unless `SENTRY_DSN` is passed |
| `cupertino_icons` | ^1.0.8 | |

The two `webview_flutter_*` platform packages are direct dependencies on
purpose — the TikTok player configures inline playback and gesture behaviour
that the facade package does not surface.

## 2. Layout

```
lib/
  app/            MaterialApp, theme, router
    swipe_eat_app.dart
    app_router.dart
  core/           what more than one feature needs
    config/       app_config.dart — every --dart-define is read here
    location/     user_location, user_position_state, place_name,
                  distance_label, open_directions
    observability/ crash_reporting.dart
    storage/      cached_at.dart
    supabase/     single_row.dart
    ui/           the design system + lunar/ effects
  features/       auth, onboarding, dashboard, restaurants, nearby, plans,
                  friends, wishlist, profile, settings
  dev/            the lunar gallery and the calendar's dev fixtures, not shipped
```

`dev/` is reached only behind a `--dart-define`: `USE_DEV_PLANS=true` swaps
`PlansController` for the fixtures in `dev/calendar_dev_data.dart`, and
`lunar_gallery.dart` is a standalone entrypoint.

### The four-folder feature shape

Every feature under `lib/features/<name>/` uses the same shape, and the
dependency arrow only points one way:

```
presentation/  →  state/  →  data/  →  models/
                                   ↘  domain/   (pure, no I/O)
```

| Folder | Holds | Must not |
|---|---|---|
| `presentation/` | Widgets | Call Supabase, hold business rules |
| `state/` | `ChangeNotifier` controllers | Build widgets |
| `data/` | Repositories — the only code touching `Supabase.instance` or `shared_preferences` | Know about widgets |
| `models/` | DTOs with `fromJson` | Do I/O |
| `domain/` | Pure logic (`deck_ranker.dart`) | Do I/O at all |

Four features carry a `domain/` folder — `restaurants/` (the deck ranker, meal
labels, opening hours), `friends/` (the caption and headcount rules),
`plans/` and `nearby/` — one apiece for the logic worth testing without a fake.

## 3. State management

`ChangeNotifier` + `AnimatedBuilder`. No Riverpod, no Bloc, no
`get_it`/`provider` — the app has one long-lived controller and per-tab
controllers each constructed by their own tab, so nothing needs a container to
find them (D2).

Conventions the controllers follow:

- **Own the flags.** `loading`, `error`, and where relevant `isStale` live on
  the controller, not in the widget.
- **Sequence concurrent loads.** `DeckController._loadGeneration` means only
  the newest request may publish; a slow earlier response cannot overwrite a
  fresher one. Any controller with a retry button needs this.
- **Optimistic writes hold their future.** The deck's card flies out before the
  write lands, so `recordSwipe` keeps the in-flight future per restaurant.
  Rewind, which is what used to await it, went with D84; the held future is
  still the pattern for any write a later action has to sequence behind.
- **Inject the platform.** Anything reaching a platform channel is
  constructor-injected with a default (`resolvePosition` on `DeckController`,
  the location resolver on the onboarding page), because `flutter test` has no
  geolocator implementation.
- **Lazy repository construction.** Repositories resolve
  `Supabase.instance` per call rather than in their constructor, so a page can
  be built in a test without an initialised client — and the failure belongs to
  the request, where it can be caught and retried.
- **Account state is one shared instance.** `LikesController.instance`,
  `FriendsController.instance`, `PlansController.instance`,
  `WishlistController.instance` (since D151 — the detail page and the Wishlist
  screen each used to build their own and refetch the list per open). Pages
  take the instance as a constructor default and tests inject a fake. Sign-out
  reaches them all through `LikesController.reset`, which is the one place the
  auth stream is watched.
- **Independent reads go out together.** `PlansController.refresh` awaits
  `(list, stats).wait` after the one write both depend on, not one after the
  other. Two RPCs with nothing between them is one round trip, not two.

## 4. Routing

`go_router`, `createRouter(AuthController)` in `lib/app/app_router.dart`, with
`refreshListenable` on the controller so a session change re-runs the redirect.

| Path | Notes |
|---|---|
| `/` | Redirects to whichever of splash/welcome/onboarding/dashboard is owed |
| `/splash` | Held until session **and** profile both resolve |
| `/login`, `/register` | Both redirect to `/welcome` — kept so old links land somewhere |
| `/welcome` | The signed-out screen (S1) |
| `/signup`, `/signup/phone` | |
| `/onboarding` | While `profiles.onboarded_at` is null |
| `/dashboard` | The five-tab shell: Swipe, Nearby, Bites, Calendar, You |
| `/settings` | |
| `/friends` | The social graph and its requests |
| `/wishlist` | |
| `/plans/new`, `/plans/:id`, `/plans/:id/invite` | Make a plan, open it and vote on the time, invite to it |
| `/restaurant/:id` | By **id**, not by a payload object |

Two details that matter:

- **The splash hold** prevents the cold-start flash of the wrong screen. The
  redirect stays on splash until both the session and the profile have
  resolved, because either alone is not enough to know where the user belongs.
- **`/restaurant/:id` routes by id**, replacing an earlier design that passed a
  serialized payload via `extra`. The payload version silently dropped fields
  (`videoUrl` among them) and could not survive a deep link.

## 5. Offline

Three `shared_preferences` caches, each versioned in its key
(`deck_cache_v1`) and scoped to the user id so one account never sees another's
data:

| Cache | File | Expiry |
|---|---|---|
| Deck | `restaurants/data/deck_cache.dart` | 7 days |
| Profile | `profile/data/profile_cache.dart` | — |
| Visit prompts | `restaurants/data/visit_prompt_cache.dart` | — |

`core/storage/cached_at.dart` is the shared staleness helper. A cached deck is
always **labelled** as stale (D17); a saved deck shown as live misrepresents how
close those places are.

## 6. Error handling

Catches are narrow — `PostgrestException`, `AuthException`,
`FunctionException`, `StorageException` — not bare `catch (e)`. `AuthRepository`
maps each to a sentence a user can act on rather than surfacing the raw
message.

`core/supabase/single_row.dart` (`asSingleRow`) normalises the
"RPC returned a one-row table" shape that several `returns table(...)`
functions produce.

Crash reporting is `sentry_flutter`, initialised in
`core/observability/crash_reporting.dart` and **off unless `SENTRY_DSN` is
passed**, so local runs and CI report nothing. The release name comes from
`version` in `pubspec.yaml`, which `sentry_flutter` reads from the bundle —
there is no second copy to keep in sync.

## 7. Assets

Both bundled rather than fetched, because the app serves a cached deck with no
connection and a first offline launch that fell back to a platform font would
undo the redesign (D8):

- **Fonts** — **Bricolage Grotesque** (600/700/800, the display face) and
  **Instrument Sans** (400/500/600/700, the text face), all as static
  instances cut from the upstream variable fonts. Flutter picks a face by the
  declared weights and cannot instance a variable axis from a `fontWeight`
  alone, so shipping the variable TTF silently breaks every weight above 400.
  Lexend was removed when the two faces returned on 2026-09-04. Licences sit
  next to the files.
- **Lottie** — `assets/lottie/`, a few KB each. Deliberately small and
  abstract: a spinner, a heart, a location pulse. Not illustrations.

Network images are not assets, but the one rule about them lives here: **a
small thumbnail decodes at the size it is painted.** `Image.network` with no
`cacheWidth` decodes the source at its own size — a 1200 px photo is ~7 MB of
pixels in the image cache to paint a 40 dp thumbnail, and the cache is 100 MB.
Every small site (avatars, wishlist and dish thumbs, plan logos, calendar
rings, map pins, the Bites tile) passes `cacheWidth: cachePx(context, size)`,
or wraps a `NetworkImage` in `ResizeImage` where it is a `DecorationImage`
(D151). Full-bleed photos — the card, the hero — are left alone: their paint
size is the source size. There is still **no disk cache**; a cold start
re-downloads every thumbnail. `cached_network_image` is the fix, and it is a
dependency, so it waits for a cold-start measurement that says it is worth one.

## 8. Out of scope

- **A state-management package** (D2).
- **A DI container** — there is nothing to resolve.
- **Web and desktop targets.** `dev/` entrypoints run anywhere, but the app
  assumes a phone: geolocator, native sign-in sheets, inline WebView playback.
- **Runtime-fetched fonts or art** (D8).

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D2 | `ChangeNotifier` + `AnimatedBuilder`; no state-management package and no DI container. | locked 2026-08-22 |
| D8 | Fonts and Lottie art are bundled, not fetched. | locked 2026-08-31 |
| D17 | A cached deck is always labelled stale. | locked 2026-08-30 |
| D56 | The splash route holds until session **and** profile resolve, so cold start never flashes the wrong screen. | locked 2026-08-22 |
| D57 | `/restaurant/:id` routes by id; the earlier `extra`-payload route dropped fields and could not deep-link. | locked 2026-08-29 |
| D58 | Repositories resolve `Supabase.instance` per call, not in their constructor, so widgets are testable without an initialised client. | locked 2026-08-29 |
| D59 | Catches name their exception type; `AuthRepository` maps each to an actionable sentence. | locked 2026-08-29 |
| D60 | Platform-channel dependencies are constructor-injected with defaults, because `flutter test` has no implementation for them. | locked 2026-08-29 |
