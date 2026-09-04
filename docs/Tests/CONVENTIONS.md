Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-04
Cross-references: [General/RUNBOOK.md](../General/RUNBOOK.md), [Frontend/STACK.md](../Frontend/STACK.md), [Features/Swipe-Deck.md](../Features/Swipe-Deck.md)

# Testing Conventions

**333 tests, all passing; `flutter analyze lib test` reports no issues**
(verified 2026-09-04).

## 1. Framework

`flutter_test` only. No `mockito`, no `mocktail`, no build-runner codegen —
every double in this repo is **hand-written** (D69).

The reason is that the repositories have small, stable interfaces, and a
hand-written fake that `implements RestaurantRepository` fails to compile the
moment the interface changes. A generated mock keeps compiling and starts
lying. That property is the whole argument.

## 2. Placement

`test/` mirrors `lib/` exactly:

```
lib/features/restaurants/domain/deck_ranker.dart
  → test/features/restaurants/deck_ranker_test.dart
```

The intermediate layer folder (`domain/`, `data/`, `state/`) is dropped in the
test path — the feature folder plus the file name is unambiguous.

## 3. Coverage map (2026-09-04)

```
test/
  app/
    app_router_test.dart                     redirects, the splash hold
  core/
    location/  open_directions_test, user_location_test
    supabase/  single_row_test
    ui/        design_tokens_test, hex_color_test, rating_label_test,
               tiktok_thumbnail_placeholder_test
  features/
    auth/         app_user_test, auth_controller_test
                  fake_auth_repository.dart
    dashboard/    dashboard_bottom_nav_test, dashboard_tab_shell_test,
                  likes_tab_view_test,
                  restaurant_detail_page_test
    onboarding/   onboarding_draft_test, onboarding_flow_test
                  fake_onboarding_repository.dart
    profile/      fake_profile_repository.dart
    restaurants/  deck_ranker_test, likes_controller_test,
                  likes_migration_test, restaurant_grid_card_test,
                  restaurant_repository_test, restaurant_test
                  fake_restaurant_repositories.dart
    settings/     settings_page_test
  support/
    widget_test_support.dart
```

### What is well covered

- **Pure logic** — `deck_ranker_test.dart` is the highest-value file in the
  suite: ranking is the product's core algorithm and it has no I/O, so it is
  tested directly with no fake at all.
- **Models** — `restaurant_test`, `app_user_test`, `onboarding_draft_test`
  cover `fromJson` and the null-defensiveness the DTOs promise.
- **Controllers** — `auth_controller_test`, `likes_controller_test`.
- **The router** — `app_router_test` covers the redirect matrix and the splash
  hold, which is the cold-start correctness property (D56).
- **Design tokens** — 42 tests, including the palette rules themselves (warm
  blacks, surface stacking order, one non-orange accent). That is what made the
  Ngap retint safe to land in one commit.
- **Widget layout under stress** — `restaurant_detail_page_test` asserts no
  overflow on a small phone, a narrow phone and a tablet, plus a long title at
  a huge text scale. That pattern is worth copying to any new screen;
  `dashboard_bottom_nav_test` is the copy, extended to the tween's
  intermediate frames.
- **The bottom nav** — `dashboard_bottom_nav_test` covers the one-current-tab
  contract (fill, ink, filled-vs-outline glyph, the single drawn label), the
  flex tween, the 1.3x text-scale clamp, and the semantics of all five tabs
  including that each one can actually be *activated* by a screen reader.

### Gaps

| Not covered | Why it matters |
|---|---|
| `DeckController` | The most complex controller in the app — `_loadGeneration` sequencing, the optimistic-write/rewind race, the daily limit's unknown-count branch. `deck_ranker_test` covers the algorithm, not the orchestration |
| `SwipeDeck` widget | Gesture thresholds (110 / −140 / `\|dx\|`), motion, the match moment |
| `ExploreController`, `VisitPromptController` | No tests |
| `ProfileRepository` | A fake exists; nothing exercises the real one |
| `TikTokPlayerCache` | The bound-at-5 eviction rule and "the watched player is never evicted" (D39) are asserted only by reasoning |
| Edge functions | No Deno test suite for `delete-account`, `legal`, `refresh-thumbnails` |
| RLS policies | No pgTAP suite. Policy correctness rests on review |

`fake_profile_repository.dart` with no matching test file is the clearest
signal here — the double was written for other tests to lean on, and the
repository itself was never covered.

## 4. Writing a fake

Rules, all visible in `fake_restaurant_repositories.dart`:

- **`implements` the real interface**, never `extends` it. A signature change
  must break the build.
- **Live next to the tests that use them**, named `fake_*.dart`, not in
  `support/`. A fake is test data, not infrastructure.
- **Provide a fixture helper** — `testRestaurant(int id, {String? name})`
  builds a minimal but *real* `Restaurant`, so no test hand-assembles a model.
- **Record calls when the test needs to assert them**, rather than being
  stubs-only. `undo_swipe`-style behaviour is only assertable if the fake
  remembers what happened.
- Fakes are shared across a feature's tests: one
  `fake_restaurant_repositories.dart` serves the repository, controller and
  widget tests.

**A change to a repository interface lands in its fake in the same commit.**
This is not optional — `FakeSwipeRepository` and `FakeRestaurantRepository`
implement the real interfaces, so every signature change reaches them.

## 5. Widget test support

`test/support/widget_test_support.dart` exists because Flutter widget tests
have no real network and no platform channels:

- **`transparentPng`** — a decodable 1×1 transparent PNG, and
  `ImageHttpOverrides`, a fake `HttpClient` stack that answers every image
  request with it. Without this, any widget with a `NetworkImage` throws in
  tests. Every card in this app has one.
- Platform-channel dependencies are **constructor-injected** rather than
  mocked at the channel level: `DeckController` takes `resolvePosition`, the
  onboarding page takes a location resolver, tabs take their controllers
  (`/// Injected by tests; in the app the tab builds its own`). `flutter test`
  has no geolocator implementation, so this is the only way those paths are
  reachable (D60).

## 6. Running

```bash
flutter analyze
flutter test
flutter test test/features/restaurants/deck_ranker_test.dart   # while iterating
```

Both commands must pass before a change is done. Run the minimum needed while
working; the full suite takes about 6 seconds, so there is no excuse for
skipping it before a commit.

## 7. CI

`.github/workflows/ci.yml` — on every pull request and every push to `main`:
set up Flutter **3.47.1**, cache pub packages, `flutter pub get`,
`flutter analyze`, `flutter test`. Nothing else. No coverage gate, no
integration stage.

## 8. What tests cannot reach

Three behaviours are platform-level and are exercised by neither command. They
need a device smoke test before a release:

1. The card-to-fullscreen TikTok player handover.
2. Sentry initialisation with a real DSN.
3. The offline deck fallback, in airplane mode.

## 9. Out of scope

- **A mocking framework** (D69).
- **Golden/screenshot tests.** The layout-under-stress assertions in
  `restaurant_detail_page_test` cover the failure mode goldens would, without
  the maintenance.
- **Integration / `integration_test` driver tests.** The three device
  behaviours above are the case for them; nothing else needs one.
- **A coverage percentage gate.** The named gaps in §3 are more useful than a
  number.

## 10. Decision log

| ID | Decision | Status |
|---|---|---|
| D69 | Hand-written fakes that `implements` the real interface, not a mocking framework. A fake fails to compile on an interface change; a generated mock keeps lying. | locked 2026-08-22 |
| D60 | Platform-channel dependencies are constructor-injected with defaults, so tests can drive them. | locked 2026-08-29 |
| D70 | Fakes live beside their tests as `fake_*.dart`, not in `support/` — a fake is test data, not infrastructure. | locked 2026-08-22 |
| D71 | An interface change lands in its fakes in the same commit. | locked 2026-08-31 |
| D72 | Widget tests stub the HTTP image stack globally via `ImageHttpOverrides`, because every card in the app carries a network image. | locked 2026-08-29 |
| D73 | Layout tests assert no-overflow across phone/narrow/tablet plus a huge text scale, in place of golden tests. | locked 2026-08-29 |
