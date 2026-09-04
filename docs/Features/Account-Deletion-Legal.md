Status: SHIPPED
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Release/STORE.md](../Release/STORE.md), [Profile-Preferences.md](Profile-Preferences.md), [Backend-Schema.md](Backend-Schema.md), [Auth.md](Auth.md)

# Account Deletion & Legal Pages

Both stores require these, and neither is optional for an app that lets people
create an account: Google Play's **Data deletion** policy and App Store
guideline **5.1.1 (v)**.

Files: `supabase/functions/delete-account/`, `supabase/functions/legal/`,
`lib/features/settings/presentation/settings_page.dart`,
`lib/features/auth/data/auth_repository.dart`,
`lib/features/auth/state/auth_controller.dart`,
`lib/core/config/app_config.dart`, `ios/Runner/PrivacyInfo.xcprivacy`.

## 1. In-app deletion

Settings → Delete account → `AuthController.deleteAccount()` →
`AuthRepository.deleteAccount()` → the `delete-account` edge function.

`verify_jwt = true` on this one, deliberately: the platform rejects an
unauthenticated caller before the function runs, so the function never has to
work out who is asking. It deletes **the calling user's own** `auth.users` row
and nothing else.

**Deleting that one row is enough**, and that is a schema property, not a
coincidence. `profiles.id` references `auth.users (id) on delete cascade`, and
every per-user table cascades from `profiles`:

```
auth.users
  └── profiles                (on delete cascade)
        ├── swipes            (on delete cascade)
        ├── quiz_responses    (on delete cascade)
        ├── profile_cuisines  (on delete cascade)
        ├── profile_dietary_tags (on delete cascade)
        └── reviews.user_id   (on delete set null)
```

`reviews.user_id` is `set null` rather than cascade — a review is content about
a restaurant, not personal data to erase, so it survives its author
anonymously. With 6 reviews and no user write path, this is theoretical today.

`SettingsPage` holds a `_deleting` flag so the row cannot be double-tapped and
the UI shows the operation in flight.

## 2. The public legal pages

The `legal` edge function serves three static pages:

| Path | Page | Required by |
|---|---|---|
| `/functions/v1/legal/privacy` | Privacy policy | Both stores |
| `/functions/v1/legal/delete-account` | Deletion instructions | **Google Play, as a web URL** reachable without installing the app or signing in |
| `/functions/v1/legal/terms` | Terms of use | Store forms |

`verify_jwt = false`, because these must open in any browser with no key. They
are static text and read nothing from the database, so there is nothing here to
protect.

The app links to them from Settings via `url_launcher`, against
`AppConfig.legalBaseUrl` — overridable by `--dart-define`, defaulting to the
project's own function URL.

The Google Play requirement is the reason this is an edge function and not an
in-app screen: Play needs a URL a reviewer can open cold, with no app and no
account.

## 3. iOS privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy`, wired into the Xcode project's build
resources. Declares the app's data collection and its required-reason API use.
Apple rejects builds without it.

`Info.plist` also carries `ITSAppUsesNonExemptEncryption` (the export-compliance
declaration) and `CFBundleName` = "Swipe Eat".

## 4. Known gaps

- **The wording has not been reviewed by a lawyer.** It is a plain-language
  description of what the app actually does. Flagged in the function's own
  header comment and in [Release/STORE.md](../Release/STORE.md).
- **The pages are static text in a TypeScript file.** Editing them means
  redeploying the function.
- **Deletion is immediate and unconfirmed by email.** No grace period, no
  recovery window.
- The privacy page notes that thumbnails come from TikTok and are subject to
  TikTok's own privacy policy when they play — worth re-checking if the embed
  approach changes.

## 5. Out of scope

- **Data export** ("download my data"). Neither store requires it for this
  app's data; GDPR would.
- **A deletion grace period** or account reactivation.
- **Legal review.** Needed before real users, but it is not an engineering
  task.

## 6. Decision log

| ID | Decision | Status |
|---|---|---|
| D50 | Deleting `auth.users` is the whole deletion path; the cascade does the rest. No bespoke cleanup code to drift out of sync with the schema. | locked 2026-08-31 |
| D51 | `reviews.user_id` is `set null`, not cascade — a review is content about a restaurant, not personal data. | locked 2026-08-22 |
| D52 | Legal pages are an edge function, not in-app screens, because Google Play needs a URL openable with no app and no account. | locked 2026-08-31 |
| D53 | `delete-account` keeps `verify_jwt = true` so the platform rejects unauthenticated callers before the function runs. | locked 2026-08-31 |
