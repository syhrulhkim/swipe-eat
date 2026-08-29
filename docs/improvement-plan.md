# Swipe Eat — implementation improvement plan

Audit of the app as it stands on 29 August 2026, and a phased plan to improve
it. Each phase is independently shippable, in the same spirit as
`docs/backend-plan.md`; nothing here requires a rewrite or a change of
framework.

Findings come from reading the repo (`lib/`, `test/`, `supabase/migrations/`),
from the Supabase project's own security and performance advisors, and from
current published guidance, which is linked at the end.

## 0. What is already right

Worth stating first, because a plan that lists only problems invites work that
is not needed.

- **Row Level Security is in good shape.** All 25 `auth.uid()` calls in the
  migrations are already written as `(select auth.uid())`, which lets Postgres
  cache the result per statement instead of evaluating it per row. Every one of
  the 21 policies names its roles with a `to` clause, the four `security
  definer` functions all pin `set search_path`, and the security advisor
  reports no policy problems at all.
- **The publishable key in `AppConfig` is intentional, not a leak.** RLS is the
  security boundary, and the comment in the file says so.
- **The test base is real.** 297 tests across models, repositories,
  controllers, the router and several widget trees, with hand-written fakes
  rather than a mocking framework. That is a solid base to build on.
- **Auth and routing are structured well.** `AuthController` is a
  `ChangeNotifier` wired to `GoRouter` through `refreshListenable`, and the
  redirect holds on the splash route until the session and profile both
  resolve, so there is no flash of the wrong screen on cold start.
- **The Supabase performance advisor's ten "unused index" rows are noise.** The
  project has almost no traffic yet, so nothing has had a chance to use them.
  Re-check after real usage; do not drop them now.

## 1. Phase 0 — housekeeping that costs almost nothing

**Continuous integration.** There is no `.github/` directory, so nothing runs
`flutter analyze` or `flutter test` except by hand. Since both already pass,
a single workflow on pull requests and pushes to `main` — set up Flutter, cache
`.pub-cache` keyed on `pubspec.lock`, `flutter analyze`, `flutter test` — turns
that into a guarantee for near-zero effort. Building and signing for TestFlight
can come later; the quality gate is the valuable part.

**The README is wrong.** It still documents a Laravel bearer-token API,
`flutter_secure_storage`, `API_BASE_URL` and a local demo account, all of which
were deleted when the app moved to Supabase. Anyone new to the repo would be
misled on their first read. Rewrite it around the actual stack: Supabase, the
`--dart-define` values in `AppConfig`, the bundled SDK in `flutter-sdk/`, and
how to run the app and the tests.

**Enable leaked-password protection.** This is the only security advisor
finding: Supabase Auth can check new passwords against HaveIBeenPwned, and the
check is currently off. It is one toggle in the dashboard.

**Ignore the vendored SDK.** `flutter-sdk/` is a full Flutter checkout sitting
untracked in the working tree. Add it to `.gitignore` so nobody commits it by
accident.

**Commit the working tree.** Roughly forty files are modified or untracked,
including the whole Supabase migration set, the onboarding, quiz, profile and
restaurants features, and the new `lib/core/ui/lunar/` components. That is
several features' worth of work living in one uncommitted pile. Split it into
themed commits before it grows further.

**Consider stricter analysis.** `analysis_options.yaml` includes
`flutter_lints` and nothing else. Turning on a few extra rules — in particular
`prefer_const_constructors`, `unawaited_futures` and
`avoid_catches_without_on_clauses` — would catch a class of issue the plan
mentions below at review time rather than at runtime.

## 2. Phase 1 — break up `dashboard_page.dart`

`lib/features/dashboard/presentation/dashboard_page.dart` is 3,571 lines and
46 classes: the shell, the bottom navigation, all four tabs, the swipe deck,
the floating header, the restaurant detail page and its supporting widgets. It
is more than a third of the app's source.

The structural problem is not the length itself, it is where the data calls
live. Repositories are constructed inside widget state and awaited there:

```dart
final restaurants = await RestaurantRepository().search(...);   // line 376
final question = await QuizRepository().fetchActiveQuestion();  // line 609
final restaurants = await RestaurantRepository().fetchDeck(...); // line 1187
final user = await ProfileRepository().updateLocation(...);      // line 1222
await SwipeRepository().record(...);                             // line 1330
```

Flutter's own architecture guidance puts data access behind a view model and
the repository behind the view model — views hold layout, animation and simple
conditionals, and nothing else. Constructing a repository inside a `State`
also makes the widget untestable without a live Supabase instance, which is
why the existing widget tests cover the detail page and the likes tab but not
the deck.

**The fix is not a new state-management framework.** `ChangeNotifier` plus
constructor injection — exactly what `AuthController` and `LikesController`
already do — is what the official guide endorses. Adding Riverpod or bloc here
would be churn dressed up as improvement. The gap is *where the logic lives*,
not *which library holds it*.

Suggested sequence, each step shippable on its own:

1. Move `RestaurantDetailPage` and `RestaurantDetailData` into
   `features/restaurants/presentation/` and `features/restaurants/models/`.
   They are already the best-tested part of the file and have no dependency on
   the dashboard shell.
2. Give the deck a `DeckController extends ChangeNotifier` in
   `features/restaurants/state/`, holding the card list, the loading and error
   states, the preload cache and the swipe recording. Inject the repositories
   through its constructor, defaulting to real ones, so tests can pass fakes
   the way `fake_restaurant_repositories.dart` already does.
3. Do the same for the quiz tab (`QuizController`) and the profile tab, then
   move each tab into its own file under its feature directory.
4. Leave `dashboard_page.dart` as the shell and bottom navigation only.

Expect the file to end up under 400 lines, with the deck finally coverable by
widget tests.

## 3. Phase 2 — pay down the TikTok player debt

These items were found during the earlier player-error review, confirmed, and
deliberately deferred. They are listed here so they do not get lost.

- **`_tiktokPlayerCache` is unbounded.** Every card that has ever been visible
  keeps a live `WebViewController`. WebViews are expensive — memory leaks and
  disappearing views with many simultaneous instances are long-standing,
  well-documented Flutter issues — so this grows until the OS starts killing
  things. Cap it (an LRU of roughly five: current, two ahead, two behind) and
  dispose what falls out.
- **Hidden audio can double up.** The deck keeps players alive in an
  `IndexedStack`, and fullscreen creates a second controller for the same
  video. Pause off-screen players explicitly and hand fullscreen the existing
  controller instead of building another.
- **The error branch is nearly dead.** `snapshot.hasError` only fires for a
  failed future, not for a page that loads and then fails. Attach
  `onWebResourceError` in the `NavigationDelegate` so a real load failure
  surfaces the retry UI.
- **Fullscreen WebView navigation is unguarded.** A tap inside the embed can
  navigate the WebView anywhere. Add a `NavigationDelegate` that only allows
  TikTok hosts.
- **`restaurants.video_url` has no unique index.** Two rows can point at the
  same video, which then collides in the URL-keyed player cache. Add the index
  in a migration.
- **The postMessage retry loop was lost** in the fix that switched to
  `loadRequest`. If autoplay ever proves unreliable on a real device, that
  unmute/play retry is the thing to restore.

**Do not migrate to a native video player.** Research on Flutter video feeds
does favour native players (`video_player`, `media_kit`) over WebViews for
performance, and that advice is sound — but it does not apply to TikTok
content, which is licensed through TikTok's embed player. Native playback only
becomes relevant if Swipe Eat ever hosts its own video.

Related: `scripts/scrape_tiktok.py` should be reviewed against TikTok's
developer terms before it feeds anything user-facing. Metadata harvesting and
video re-hosting are treated very differently.

## 4. Phase 3 — routing and error handling

**`/restaurant` cannot be deep-linked or restored.** The route reads its
payload from `state.extra`, and when that is missing it builds a
`RestaurantDetailData` full of zeros and empty strings — a blank page that
looks like a bug rather than an error. Change the route to `/restaurant/:id`,
fetch through `RestaurantRepository.fetchById`, and show a real "not found"
state. This also makes the screen survive process death and reachable from a
future share link or push notification.

**Eleven `catch (_)` sites swallow everything.** Some are deliberate and
correct — `LikesAuthEvents` catching an uninitialised Supabase in tests, for
instance — but as a blanket habit it hides real failures. Narrow each to the
exception it actually expects, and once Phase 4 lands, report the unexpected
ones instead of dropping them.

## 5. Phase 4 — observability

Right now a crash on a user's phone leaves no trace: there is no crash
reporting, no error logging and no analytics. Before any real user testing,
that needs to change.

**Recommendation: Sentry.** There is no Firebase in this stack, and adding the
whole Firebase surface just for Crashlytics costs more than it returns.
Sentry's Flutter SDK gives crashes, handled errors, breadcrumbs, release
tagging and tracing in one place, and its free tier is enough for this stage.
Crashlytics would be the better answer only if Firebase arrives for other
reasons.

Wire it as: `SentryFlutter.init` in `main.dart`, `GoRouter` navigation
breadcrumbs, the narrowed catch sites from Phase 3 reporting handled errors,
and the release tagged from `pubspec.yaml`'s version so a bad build is
identifiable.

Product analytics — how far users get through onboarding, swipe-through rate,
which cards get opened — is a separate, later question, and worth deciding
deliberately rather than pulling in with the crash SDK.

## 6. Phase 5 — offline behaviour (optional)

The app currently needs the network for everything: the deck, the likes tab,
the quiz, the profile. On a phone in a mall basement that is a blank screen.

Start small. The likes tab already has a device-local `LikesStore`; extend the
same pattern to cache the last deck response and the profile, and show cached
content with a staleness marker when a request fails. That covers the common
case for a few hours of work.

A sync engine (PowerSync, Brick) keeps a full SQLite replica in sync and
handles offline writes properly — real capability, real cost. PowerSync's own
guidance is that it is overkill when all you need is caching. Revisit only if
offline use becomes a product requirement rather than a nicety.

## 7. Status

All six phases were delivered on 29–30 August 2026, on
`feat/supabase-migration`, one commit per phase.

| Phase | Work | Commit | Status |
| --- | --- | --- | --- |
| 0 | CI, README, `.gitignore`, lints | `3aa79ba` | Done |
| 1 | `dashboard_page.dart` decomposition | `9fba039` | Done |
| 2 | TikTok player debt | `e1953a6` | Done |
| 3 | Route by id, narrow the catches | `1d9b25b` | Done |
| 4 | Sentry | `f9bd299` | Done |
| 5 | Offline cache | `a23dad7` | Done |

Two items from Phase 0 are not code and remain open:

- **Leaked-password protection** is a Supabase dashboard toggle
  (Authentication → Providers → Email) and has to be turned on by hand.
- **`SENTRY_DSN`** has to be created in Sentry and passed to release builds as
  a `--dart-define`; with no DSN the app simply does not report, which is the
  intended default for local runs and CI.

Three behaviours are platform-level and were not exercised by
`flutter analyze` or the test suite, so they want a device smoke test: the
card-to-fullscreen player handover, Sentry initialisation with a real DSN, and
the offline fallback in airplane mode.

## Sources

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
  and the
  [dependency injection case study](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Supabase Row Level Security performance guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase leaked password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [webview_flutter memory leak issue](https://github.com/flutter/flutter/issues/96583)
  and [multiple WebViews disappearing](https://github.com/flutter/flutter/issues/61795)
- [Very Good Ventures on video playback in Flutter feeds](https://verygood.ventures/blog/video-playback-flutter-feed/)
- [TikTok embed player documentation](https://developers.tiktok.com/docs/en/embed-player)
  and [TikTok developer terms of service](https://www.tiktok.com/legal/page/global/tik-tok-developer-terms-of-service/en)
- [Production-ready Flutter CI/CD with GitHub Actions](https://www.freecodecamp.org/news/how-to-build-a-production-ready-flutter-ci-cd-pipeline-with-github-actions-quality-gates-environments-and-store-deployment/)
- [Sentry vs Crashlytics for Flutter](https://pro.codewithandrea.com/flutter-in-production/04-error-monitoring/02-sentry-vs-crashlytics)
- [Supabase + PowerSync guide](https://docs.powersync.com/integrations/supabase/guide)
  and [offline-first Flutter with Brick](https://supabase.com/blog/offline-first-flutter-apps)
