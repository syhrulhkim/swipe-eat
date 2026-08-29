# Auth setup

The app authenticates against Supabase Auth (project `vpcldlhqpvunnuexecgn`).
Email/password works out of the box. Google and Apple sign-in need console work
that cannot live in this repo — until it is done the two buttons **hide
themselves**, so an unconfigured build still runs and still signs people in.

## Email/password

Nothing to configure. Two behaviours worth knowing:

- **Email confirmation is ON** (Supabase dashboard → Authentication →
  Providers → Email → "Confirm email"). `signUp` therefore returns a user but
  **no session**: the account only works after the emailed link is opened.
  `AuthController.register` surfaces that as a notice and routes to the login
  page rather than pretending the user is signed in. If you turn confirmation
  off, `SignUpOutcome.signedIn` starts coming back and the app handles it
  without a code change.
- **Supabase rejects unroutable domains.** `@swipeeat.test` and friends fail
  with `email_address_invalid`, so test accounts need a real domain.

### Custom SMTP: Mailtrap sandbox

Auth email (confirmation + password reset) goes through the Mailtrap **Email
Testing** sandbox: every message is captured in the Mailtrap inbox and nothing
is ever delivered to a real address. That is deliberate while the app is in
testing — no stray confirmation mail reaches real people, and Supabase's
built-in sender (rate-limited to a couple of emails an hour, team-member
addresses only) stops being a bottleneck.

Configure it in the Supabase dashboard → Project Settings → Authentication →
**SMTP Settings** → enable "Custom SMTP":

| Field | Value |
|---|---|
| Host | `sandbox.smtp.mailtrap.io` |
| Port | `2525` |
| Username | `347a8a84223f4e` |
| Password | Mailtrap → Email Testing → My Inbox → SMTP Settings → Show Credentials |
| Sender email | `no-reply@swipeeat.app` (sandbox delivers nothing, so any address works) |
| Sender name | `Swipe Eat` |

Captured mail is read in the Mailtrap web UI (account "abu gembira", inbox
"My Inbox"), or over the API (`GET /api/accounts/1246979/inboxes/1746640/messages`
with an `Api-Token` header — keep the token in a header file, never inline in
a command, same rule as the thumbnail refresh secret).

**Before real users:** the sandbox swallows all mail, so a real launch must
switch to Mailtrap **Email Sending** (host `live.smtp.mailtrap.io`, username
`api`, password = the API token, plus a verified sending domain) — or any
other production SMTP.

### Known limitation: the emailed links land outside the app

Both the confirmation link and the password-reset link redirect to the
project's **Site URL** (Supabase dashboard → Authentication → URL
Configuration), which is still the default `http://localhost:3000`.

- *Confirmation* works anyway — Supabase confirms the account server-side
  before redirecting, so only the final browser tab is dead. Cosmetic, but it
  looks broken on a device; set the Site URL to something real.
- *Password reset* does **not** work end to end. The email sends and
  `AuthController.sendPasswordReset` reports success, but the recovery session
  arrives in the redirect URL fragment, which the app never sees: there is no
  custom URL scheme registered and no "set a new password" screen. Until that
  is built the "Forgot password?" link is a dead end.

Finishing it needs the same iOS work as Google sign-in, so do them together:
register a URL scheme in `ios/Runner/Info.plist` and
`android/app/src/main/AndroidManifest.xml`, add it to the dashboard's redirect
allow-list, pass it as `redirectTo` on `resetPasswordForEmail`, and handle
`AuthChangeEvent.passwordRecovery` in `AuthController._handleAuthState` (it is
currently swallowed by the `default:` branch) by routing to a new
set-new-password page.

### The seeded demo account

`demo@swipeeat.test` / `password` exists as a real `auth.users` row (created
directly, which is the only way to get a `.test` address in). Hand-inserted
rows must have empty strings — not NULL — in GoTrue's token columns
(`confirmation_token`, `recovery_token`, `email_change`,
`email_change_token_new`, `email_change_token_current`, `phone_change`,
`phone_change_token`, `reauthentication_token`), or password login fails with
a 500 `Database error querying schema`. Its `onboarded_at` is deliberately
null, so the first sign-in walks the onboarding wizard once.

Verify a login end to end without the app:

```bash
curl -s -X POST \
  'https://vpcldlhqpvunnuexecgn.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: <publishable key>' -H 'Content-Type: application/json' \
  -d '{"email":"demo@swipeeat.test","password":"password"}'
```

## Google sign-in

Native (`google_sign_in` 7.x) → `signInWithIdToken`, so there is no browser
round trip. Three ids are involved and they are easy to mix up:

| Id | Where it comes from | What uses it |
|---|---|---|
| **Web** client id | Google Cloud console → Credentials → OAuth client, type *Web* | the audience Supabase validates; passed as `serverClientId` **and** entered in the Supabase dashboard |
| **iOS** client id | same console, type *iOS*, bundle id must match `Runner` | passed as `clientId` on iOS |
| **Android** client | same console, type *Android*, needs the signing SHA-1 | not passed in code; Google matches it by signature |

1. Create all three clients in Google Cloud.
2. Supabase dashboard → Authentication → Providers → **Google**: enable it and
   paste the **web** client id and its secret. Add the iOS and Android client
   ids to "Authorized Client IDs".
3. iOS: add the reversed iOS client id
   (`com.googleusercontent.apps.<id>`) as a `CFBundleURLSchemes` entry in
   `ios/Runner/Info.plist`.
4. Build with the ids defined:

```bash
flutter run \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios>.apps.googleusercontent.com
```

`AppConfig.hasGoogleSignIn` is what gates the button, and it checks the **web**
id — that is the one the token exchange cannot work without.

## Apple sign-in

1. Apple Developer → Certificates, Identifiers & Profiles: enable *Sign in with
   Apple* on the app id, create a Services ID and a signing key.
2. Supabase dashboard → Authentication → Providers → **Apple**: enter the
   Services ID (client id), team id, key id and the `.p8` key.
3. Xcode: add the *Sign in with Apple* capability to the Runner target (this
   writes `Runner.entitlements` and needs a provisioning profile that has the
   capability, so it is deliberately not committed ahead of the Apple-side
   setup).

No `--dart-define` is needed; the button appears on iOS/macOS builds and is
hidden elsewhere, because the native sheet is Apple-platform only.

**Apple sends the user's name exactly once**, on the first authorisation ever.
`AuthRepository.signInWithApple` captures it into `user_metadata` and the
profile row at that moment; there is no second chance.

## Where the pieces live

| Concern | File |
|---|---|
| Client ids and their gate | `lib/core/config/app_config.dart` |
| Supabase calls + error → sentence mapping | `lib/features/auth/data/auth_repository.dart` |
| Native provider sheets | `lib/features/auth/data/oauth_provider_client.dart` |
| Session state and the onboarding gate | `lib/features/auth/state/auth_controller.dart` |
| Splash hold that prevents the cold-start flash | `lib/app/app_router.dart` |
