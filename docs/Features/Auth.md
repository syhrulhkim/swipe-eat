Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-10
Cross-references: [General/RUNBOOK.md](../General/RUNBOOK.md), [Onboarding-Taste.md](Onboarding-Taste.md), [Account-Deletion-Legal.md](Account-Deletion-Legal.md), [Backend-Schema.md](Backend-Schema.md), [Release/STORE.md](../Release/STORE.md), [Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md)

# Auth setup

The app authenticates against Supabase Auth (project `vpcldlhqpvunnuexecgn`).

A signed-out user lands on the **welcome screen** and, from either button, on
the **sign-up screen**, which offers every way in the running build can
actually deliver:

| Way in | Gated by | Default |
|---|---|---|
| Phone (SMS) | `--dart-define=PHONE_AUTH_ENABLED=true` **and** an SMS provider in the Supabase dashboard | hidden (D113) |
| Apple | the platform — the native sheet is iOS/macOS only | shown on Apple devices |
| Google | `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` | hidden |
| Email + password | nothing; it is the fallback | shown, behind "Use email instead" (D114) |
| "Later" (no account) | `--dart-define=GUEST_BROWSING_ENABLED=true` and the anonymous provider | hidden (D115) |

Everything hides itself rather than failing at tap time. That is the whole
gating rule, and it is why email survives a design that does not have it: with
phone off, Google unconfigured and Apple absent, a build would otherwise have
no way to sign in at all.

## The screens

| Route | Screen | Notes |
|---|---|---|
| `/welcome` | `WelcomePage` | Design S1. Three real restaurants in a card stack, the headline, and two buttons that both lead to `/signup` |
| `/signup` | `SignUpPage` | Design 01b. The provider buttons, the legal line, and the email form behind "Use email instead" |
| `/signup/phone` | `PhoneSignInPage` | Number, then code. **Pushed**, so it keeps the platform transition and the swipe back |
| `/login`, `/register` | — | Redirect to `/welcome`. The pages are gone; the paths stay so an old link does not 404 |

`app_router.dart`'s redirect sends every signed-out user to `/welcome` and
holds on `/splash` until the session *and* its profile have resolved — see
[Onboarding-Taste.md](Onboarding-Taste.md) for what happens next.

The two signed-out screens show real restaurants, read anonymously
(`AuthCoverRepository`: a plain select on `restaurants` + `restaurant_images`,
both readable by `anon` — [Backend-Schema.md](Backend-Schema.md) §4). The
loader is constructor-injected, and a failure draws the cards as plain
surfaces rather than leaving a hole.

## Phone sign-in

**Not enabled.** The client is finished; the provider is not:

1. Supabase dashboard → Authentication → Providers → **Phone**: enable it and
   configure an SMS gateway (Twilio, MessageBird, Vonage, or a Textlocal-style
   local provider). This costs real money per message, which is the reason it
   is not switched on.
2. Build with the define:

```bash
flutter run --dart-define=PHONE_AUTH_ENABLED=true
```

Without step 1 the button appears and every tap fails, so the two go together.
[Release/STORE.md](../Release/STORE.md) lists it as a release-time item.

**Contact matching depends on this switch.** The
`on_auth_user_phone_verified` trigger (`after insert or update of phone,
phone_confirmed_at`) writes a peppered digest of a **verified** number into
`phone_hashes`, and that table is the only thing `match_contacts` compares
against. Nothing verifies a number while phone auth is off, so `phone_hashes`
is empty on a project whose accounts all arrived through Google, Apple or
email — the onboarding contacts step runs, reads the address book, and
correctly matches nobody. See [Friends.md](Friends.md) (D128).

What the flow does:

- **+60 only.** The country code is a fixed chip, not a picker — the app is
  Kuala Lumpur's. A leading `0` (people type `012…`) and a leading `60` are
  both stripped before `+60` is prefixed, so `012 345 6789` and `60123456789`
  reach Supabase as `+60123456789`.
- **9–10 digits** enables "Send code"; below that the button is disabled
  rather than failing.
- `auth.signInWithOtp(phone:)` sends the code; `auth.verifyOTP(type:
  OtpType.sms, phone:, token:)` exchanges it for a session. The router
  redirect then decides between the onboarding wizard and the deck.
- **Resend after 30 s**, counted down on screen. The ticker is injected so the
  widget test does not wait thirty real seconds.
- Errors land **under the field**, in the app's own sentences —
  `AuthRepository._messageFor` maps `otp_expired` (which Supabase also returns
  for a wrong code), `otp_disabled`, `phone_provider_disabled`,
  `over_sms_send_rate_limit` and `sms_send_failed`.

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

## Guest browsing ("Later")

The design's sign-up screen offers "Later". It calls
`auth.signInAnonymously()`, which needs Supabase dashboard → Authentication →
Providers → **Anonymous** switched on. It is not, so the button is hidden
behind `--dart-define=GUEST_BROWSING_ENABLED=true` (D115). Note that an
anonymous user still walks the onboarding wizard — `onboarded_at` is null on a
fresh profile either way.

## Email/password — the fallback

Nothing to configure. It lives behind "Use email instead" on the sign-up
screen: one form that switches between signing in, creating an account and
sending a reset, rather than the two pages it replaced. Two behaviours worth
knowing:

- **Email confirmation is ON** (Supabase dashboard → Authentication →
  Providers → Email → "Confirm email"). `signUp` therefore returns a user but
  **no session**: the account only works after the emailed link is opened.
  `AuthController.register` surfaces that as a notice, and the form shows it
  and flips back to sign-in rather than pretending the user is in. If you turn
  confirmation off, `SignUpOutcome.signedIn` starts coming back and the app
  handles it without a code change.
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

The design has no forgot-password flow at all, because phone needs none. So
the cheapest fix is the one already planned: switch phone on, and the email
form — dead-end reset included — goes with it (D114). If email outlives phone,
finishing the reset needs the same iOS work as Google sign-in, so do them
together: register a URL scheme in `ios/Runner/Info.plist` and
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

## Where the pieces live

| Concern | File |
|---|---|
| Client ids, the two auth defines and their gates | `lib/core/config/app_config.dart` |
| Supabase calls + error → sentence mapping | `lib/features/auth/data/auth_repository.dart` |
| The anonymous cover read for the signed-out screens | `lib/features/auth/data/auth_cover_repository.dart` |
| Native provider sheets | `lib/features/auth/data/oauth_provider_client.dart` |
| Session state and the onboarding gate | `lib/features/auth/state/auth_controller.dart` |
| Welcome (S1) | `lib/features/auth/presentation/welcome_page.dart` |
| Sign-up (01b) | `lib/features/auth/presentation/sign_up_page.dart` |
| Phone number + code | `lib/features/auth/presentation/phone_sign_in_page.dart` |
| The email fallback form | `lib/features/auth/presentation/email_auth_form.dart` |
| Wordmark, provider buttons, cover card | `lib/features/auth/presentation/auth_widgets.dart` |
| Routes, and the splash hold that prevents the cold-start flash | `lib/app/app_router.dart` |

## Decision log

| ID | Decision | Status |
|---|---|---|
| D113 | Phone sign-in is config-gated exactly like Google. The SMS provider is dashboard work with a per-message cost that this repo cannot do, so `PHONE_AUTH_ENABLED` is off by default and the button hides itself. A button that fails at tap time is worse than no button. | locked 2026-09-06 |
| D114 | Email/password stays as the fallback until phone is live, behind "Use email instead" and folded into one form. The design has no email, but phone, Google and Apple are each gated by something a developer build does not have — without email such a build could not sign in at all. | locked 2026-09-06, revisit when D113 flips |
| D115 | Guest browsing ("Later") is gated by `GUEST_BROWSING_ENABLED`, because the anonymous provider is not enabled on the project. | locked 2026-09-06 |
