Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [PLAN.md](PLAN.md), [Tests/CONVENTIONS.md](../Tests/CONVENTIONS.md), [Release/STORE.md](../Release/STORE.md), [Features/Auth.md](../Features/Auth.md)

# Runbook

Operational commands for local development, the database, and release builds.
Anything requiring a console (Google Cloud, Apple Developer, Supabase
dashboard) lives in [Features/Auth.md](../Features/Auth.md) or
[Release/STORE.md](../Release/STORE.md) instead.

## 1. Toolchain

Flutter **3.47.1** or newer — the version CI pins. A checkout can be bundled
in `./flutter-sdk` (untracked):

```bash
export PATH="$PWD/flutter-sdk/bin:$PATH"
flutter --version
```

## 2. Run the app

```bash
flutter pub get
flutter run
```

That is genuinely all of it. `SUPABASE_URL` and `SUPABASE_KEY` are compiled in
with defaults pointing at the shared project (`vpcldlhqpvunnuexecgn`), so a
fresh clone signs in and deals a real deck with no configuration. The
publishable key is meant to ship — RLS, not key secrecy, is the boundary.

Sign in with the seeded demo account: `demo@swipeeat.test` / `password`. Its
`onboarded_at` is deliberately null, so the first sign-in walks the onboarding
wizard once.

### With the social sign-ins

Both Google ids must be present or the Google button hides itself:

```bash
flutter run \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios>.apps.googleusercontent.com
```

Apple needs no define — the button appears on Apple platforms only.

### Every configurable define

All of them are read in `lib/core/config/app_config.dart`.

| Define | Default | Purpose |
|---|---|---|
| `SUPABASE_URL` | the shared project | Point at a different Supabase project |
| `SUPABASE_KEY` | that project's publishable key | Matching publishable key |
| `APP_NAME` | `Swipe Eat` | Window and task-switcher title |
| `GOOGLE_WEB_CLIENT_ID` | none | Audience Supabase validates Google tokens against |
| `GOOGLE_IOS_CLIENT_ID` | none | Identifies the app to the iOS Google sheet |
| `SENTRY_DSN` | none | Turns on crash reporting; unset means nothing is sent |
| `SENTRY_ENVIRONMENT` | `development` | Which deployment a report came from |

### Component demos

`lib/dev/` holds entrypoints that are not part of the app, for looking at
design-system pieces in isolation:

```bash
flutter run -t lib/dev/lunar_gallery.dart
```

## 3. Static analysis and tests

```bash
flutter analyze
flutter test
```

Both must pass before a change is done — CI (`.github/workflows/ci.yml`) runs
exactly these two on every pull request and every push to `main`, on Flutter
3.47.1. Run a single file while iterating:

```bash
flutter test test/features/restaurants/deck_ranker_test.dart
```

See [Tests/CONVENTIONS.md](../Tests/CONVENTIONS.md) for what is covered and how
the fakes work.

## 4. Database

Migrations under `supabase/migrations/` mirror the remote project.

```bash
supabase db push          # apply pending migrations
supabase migration list   # what is applied where
```

**A new migration goes in `supabase/migrations/` *and* through `apply_migration`
against the remote.** Doing only one desyncs the repo from the project, and the
next `db push` fights the difference.

`supabase/seed.sql` is idempotent and safe to re-run:

```bash
supabase db reset         # local only — recreates and re-seeds
```

Note the seed's known limitation: it stores absolute production Storage URLs
whose paths embed production row ids, so a fresh database serves images from
the production bucket. See `supabase/README.md`.

### Every new function needs its grants

Matching the pattern at the bottom of
`supabase/migrations/20260823093541_backend_v2_deck_rpcs.sql`:

```sql
revoke execute on function public.<name>(<args>) from public;
grant  execute on function public.<name>(<args>) to authenticated, service_role;
```

A freshly created function has `execute` granted to `PUBLIC`, which `anon`
inherits. Adding or removing a parameter changes the signature, so it is a
`drop` + `create` (not `create or replace`) and the grants must be reissued
against the new signature — otherwise Postgres keeps both overloads and the
call is ambiguous.

## 5. Edge functions

Three of them, configured in `supabase/config.toml`:

| Function | `verify_jwt` | Purpose |
|---|---|---|
| `refresh-thumbnails` | false | Caches TikTok thumbnails into Storage; called by pg_cron |
| `legal` | false | Serves the public privacy / terms / deletion pages |
| `delete-account` | true | Deletes the calling user's own account |

```bash
supabase functions deploy refresh-thumbnails
supabase functions deploy legal
supabase functions deploy delete-account
supabase secrets set THUMBNAIL_REFRESH_KEY=<random hex>
```

`config.toml` pins the `verify_jwt` flags; deploying without it defaults them
back to true, and the cron caller starts getting 401s.

The thumbnail pipeline is inert until its vault secrets exist — by design, so a
fresh database never calls production. Bootstrapping steps are in
`supabase/README.md`.

To invoke a protected function by hand, put the key in a header file. Never
inline a secret on a command line:

```bash
curl -X POST "$URL" -H @header-file -H 'Content-Type: application/json' -d '{"batch":25}'
```

## 6. The restaurant data pipeline

Four stages, each writing a file; only the last two touch Supabase. Full
detail in [Features/Restaurant-Data.md](../Features/Restaurant-Data.md).

```bash
python3 scripts/scrape_tiktok.py <handle>        # TikTok → JSON
python3 scripts/extract_restaurants.py           # captions → candidates
python3 scripts/restaurants_to_sql.py            # reviewed → INSERTs
python3 scripts/geocode_free.py                  # fill lat/lon, free sources
python3 scripts/test_scrape_tiktok.py            # self-check for map_entry
```

`scripts/geocode_places.py` is the paid Google Places alternative — it also
returns ratings, which the free path cannot. See D10 in
[DECISIONS.md](DECISIONS.md).

## 7. Release builds

```bash
# Android — upload the .aab, never an .apk
flutter build appbundle --release \
  --dart-define=SENTRY_DSN=https://...ingest.sentry.io/... \
  --dart-define=SENTRY_ENVIRONMENT=production

# iOS
flutter build ipa --release \
  --dart-define=SENTRY_DSN=... \
  --dart-define=SENTRY_ENVIRONMENT=production
```

The Sentry release name comes from `version` in `pubspec.yaml`, which
`sentry_flutter` reads from the bundle — there is no second copy to keep in
sync. With no DSN the app reports nothing, which is the intended default for
local runs and CI.

Signing, store forms, icons and screenshots: [Release/STORE.md](../Release/STORE.md).

## 8. Things that need a device, not a test

Three behaviours are platform-level and are not exercised by `flutter analyze`
or `flutter test`. Smoke-test them on hardware before a release:

- the card-to-fullscreen TikTok player handover,
- Sentry initialisation with a real DSN,
- the offline deck fallback, in airplane mode.
