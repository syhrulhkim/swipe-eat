Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
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
| `google_sign_in` | ^7.2.0 | Native Google sheet → `signInWithIdToken` |
| `sign_in_with_apple` | ^8.1.0 | Native Apple sheet |
| `crypto` | ^3.0.6 | Hashes the Apple sign-in nonce |
| `shared_preferences` | ^2.5.5 | The offline caches (deck, profile, visit prompts) |
| `url_launcher` | ^6.3.1 | Hands a maps/navigation URL to the OS; opens the legal pages |
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
    location/     user_location, place_name, distance_label, open_directions
    observability/ crash_reporting.dart
    storage/      cached_at.dart
    supabase/     single_row.dart
    ui/           the design system + lunar/ effects
  features/       auth, onboarding, dashboard, restaurants, profile, settings
  dev/            standalone demo entrypoints, not shipped
```

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

`restaurants/` is the only feature with a `domain/` folder today, because it is
the only one with logic worth testing without a fake.

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
  write lands, so `recordSwipe` keeps the in-flight future per restaurant and
  `rewind` awaits it — otherwise the undo races the insert.
- **Inject the platform.** Anything reaching a platform channel is
  constructor-injected with a default (`resolvePosition` on `DeckController`,
  the location resolver on the onboarding page), because `flutter test` has no
  geolocator implementation.
- **Lazy repository construction.** Repositories resolve
  `Supabase.instance` per call rather than in their constructor, so a page can
  be built in a test without an initialised client — and the failure belongs to
  the request, where it can be caught and retried.

## 4. Routing

`go_router`, `createRouter(AuthController)` in `lib/app/app_router.dart`, with
`refreshListenable` on the controller so a session change re-runs the redirect.

| Path | Notes |
|---|---|
| `/` | Redirects to whichever of splash/login/onboarding/dashboard is owed |
| `/splash` | Held until session **and** profile both resolve |
| `/login`, `/register` | |
| `/onboarding` | While `profiles.onboarded_at` is null |
| `/dashboard` | The five-tab shell |
| `/settings` | |
| `/explore/cuisine/:id` | From an Explore tile |
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

- **Fonts** — Lexend, four static instances (400/500/600/700) cut from the
  upstream variable font. Flutter picks a face by the declared weights and
  cannot instance a variable axis from a `fontWeight` alone. Licence sits next
  to the files.
- **Lottie** — `assets/lottie/`, a few KB each. Deliberately small and
  abstract: a spinner, a heart, a location pulse. Not illustrations.

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
