# Swipe Eat

A Flutter app for finding places to eat by swiping through restaurant cards,
backed by Supabase.

- **UI**: forui components over a custom dark glassmorphic design system
  (`lib/core/ui/glass_ui.dart`), Inter throughout.
- **Backend**: Supabase — Postgres with Row Level Security, Supabase Auth
  (email, Google, Apple), Storage for cached thumbnails, and edge functions.
- **Routing**: go_router, with redirects driven by `AuthController`.
- **Video**: TikTok clips embedded through TikTok's own player in a WebView.

## Setup

1. Install Flutter 3.47.1 or newer, or use the checkout bundled in
   `./flutter-sdk` (untracked):

   ```bash
   export PATH="$PWD/flutter-sdk/bin:$PATH"
   ```

2. Fetch dependencies:

   ```bash
   flutter pub get
   ```

3. Run:

   ```bash
   flutter run
   ```

The Supabase URL and publishable key are compiled in with defaults, so the app
runs against the shared project with no configuration. The publishable key is
meant to ship — Row Level Security, not key secrecy, is the security boundary.

## Configuration

Everything configurable lives in `lib/core/config/app_config.dart` and is
supplied with `--dart-define`:

| Define | Default | Purpose |
| --- | --- | --- |
| `SUPABASE_URL` | the shared project | Point at a different Supabase project |
| `SUPABASE_KEY` | that project's publishable key | Matching publishable key |
| `APP_NAME` | `Swipe Eat` | Window and task-switcher title |
| `GOOGLE_WEB_CLIENT_ID` | none | Audience Supabase validates Google tokens against |
| `GOOGLE_IOS_CLIENT_ID` | none | Identifies the app to the iOS Google sheet |

Both Google ids are required for native Google sign-in; with them unset the
Google button is hidden rather than failing at tap time. See
`docs/auth-setup.md` for how to obtain them and how Apple sign-in is wired.

```bash
flutter run \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

## Layout

```
lib/
  app/          MaterialApp, theme, router
  core/         config, location, Supabase helpers, design system
  features/     auth, onboarding, dashboard, restaurants, quiz, profile, settings
  dev/          standalone demo entrypoints, not shipped
supabase/
  migrations/   schema, RLS policies, RPCs — mirrors the remote project
  functions/    edge functions
  seed.sql      idempotent catalogue seed
docs/           backend plan, auth setup, dashboard spec, improvement plan
scripts/        TikTok metadata scraping helpers
```

Each feature follows the same shape: `data/` repositories, `models/`,
`state/` controllers, `presentation/` widgets.

## Tests

```bash
flutter analyze
flutter test
```

Repositories and controllers are covered by unit tests with hand-written fakes
(`test/features/**/fake_*.dart`); several screens have widget tests. CI runs
both commands on every pull request.

## Database

Migrations under `supabase/migrations/` mirror the remote project. Apply them
with the Supabase CLI:

```bash
supabase db push
```

`supabase/seed.sql` is idempotent and safe to re-run. See
`docs/backend-plan.md` for the schema's design and `supabase/README.md` for
operational notes.

## Standalone demos

`lib/dev/` holds entrypoints that are not part of the app, for looking at
components in isolation:

```bash
flutter run -t lib/dev/lunar_gallery.dart
```
