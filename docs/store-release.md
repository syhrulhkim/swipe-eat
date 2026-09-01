# Shipping Swipe Eat to Google Play and the App Store

Everything in this document is either already done in the repo (marked **done**)
or is a step only you can take, because it needs a keystore, a paid developer
account, or artwork.

The identifier is **`com.swipeeat.app`** on both platforms. It is baked into the
Android `applicationId`/`namespace` and the iOS `PRODUCT_BUNDLE_IDENTIFIER`, and
neither store lets you change it after the first published release — so if this
is not the identifier you want, change it now, before anything is uploaded.

## Read this first: renaming the bundle ID broke the social sign-ins

Google and Apple tie their OAuth credentials to the identifier, and it just
changed from `com.example.*`. Google and Apple sign-in will fail until you
re-register:

- **Google Cloud console** → the OAuth client of type *Android* is keyed by
  package name **and** signing-certificate SHA-1. Create one for
  `com.swipeeat.app` with the SHA-1 of the upload keystore you make below, and
  another with the SHA-1 that Play App Signing shows you after the first upload
  (Play re-signs your app, so the fingerprint users actually run is Play's, not
  yours). The OAuth client of type *iOS* needs bundle ID `com.swipeeat.app`.
  Feed the resulting ids in as `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID`
  dart-defines — see `docs/auth-setup.md`.
- **Apple developer portal** → the App ID must be `com.swipeeat.app` with the
  *Sign in with Apple* capability enabled, and the Service ID / key you gave
  Supabase must point at it.
- **Xcode** → the app has no entitlements file yet, and Sign in with Apple needs
  the `com.apple.developer.applesignin` entitlement baked into the *build*, not
  just enabled on the App ID. Open `ios/Runner.xcworkspace`, select the Runner
  target, go to **Signing & Capabilities**, and add **Sign in with Apple**.
  Xcode creates `ios/Runner/Runner.entitlements`, sets
  `CODE_SIGN_ENTITLEMENTS` on the target, and refreshes the provisioning
  profile. Commit both changes.

  This step was deliberately left to you rather than hand-edited into the
  project: an entitlement without a matching provisioning profile fails code
  signing, so every device build would break until the App ID above is
  configured. Do the portal work first, then the Xcode capability.

Until all of that is done, only email + password sign-in works. Apple rejects an
app whose advertised sign-in button fails — guideline 4.8 — so verify both on a
real device before submitting.

---

## Already done in this repo

| Requirement | Where |
| --- | --- |
| Real application id, not `com.example.*` | `android/app/build.gradle.kts`, `ios/Runner.xcodeproj/project.pbxproj` |
| Kotlin package moved to match | `android/app/src/main/kotlin/com/swipeeat/app/` |
| Launcher name reads "Swipe Eat", not `swipe_eat` | `AndroidManifest.xml`, `ios/Runner/Info.plist` |
| Release signing wired to an out-of-repo keystore | `android/app/build.gradle.kts` + `android/key.properties.example` |
| Targets Android 16 (API 36) | inherited from the Flutter SDK's `compileSdkVersion`/`targetSdkVersion`; nothing to change |
| iOS privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy`, wired into the Runner target's Resources phase |
| Export-compliance answer | `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` |
| In-app account deletion | Settings → Account → Delete account, calling the `delete-account` edge function |
| Public data-deletion URL | <https://vpcldlhqpvunnuexecgn.supabase.co/functions/v1/legal/delete-account> |
| Privacy policy URL | <https://vpcldlhqpvunnuexecgn.supabase.co/functions/v1/legal/privacy> |
| Terms URL | <https://vpcldlhqpvunnuexecgn.supabase.co/functions/v1/legal/terms> |
| Version at `1.0.0+1` | `pubspec.yaml` |
| Icon generation pipeline | `flutter_launcher_icons` block in `pubspec.yaml`, sources in `assets/icon/` |

The three legal pages are served by `supabase/functions/legal` with
`verify_jwt = false`, so they open in any browser with no key — which is what
Google Play's reviewers need, since they check the deletion URL before they ever
install the app.

**The wording of those pages has not been through legal review.** It is an
accurate description of what the app does today, written to satisfy the store
policies. If Swipe Eat starts collecting anything new — analytics, ads, contacts
— the pages, the iOS privacy manifest and the Play Data safety form all have to
be updated together.

---

## Still needed from you

### 1. Accounts

- Google Play Console developer account: US$25, one-time.
- Apple Developer Program: US$99/year. Required even to use TestFlight.
- A **personal** (not organisation) Play account created after Nov 2023 must run
  a closed test before it can apply for production access. Google has changed
  the tester count and duration more than once — read the exact current
  numbers on the "Ready for production" page in your own Play Console rather
  than trusting any figure quoted elsewhere, including this document.

### 2. Icons and screenshots

Drop the two source PNGs into `assets/icon/` (`app_icon.png` and
`app_icon_fg.png`, specs in `assets/icon/README.md`), then run:

```bash
dart run flutter_launcher_icons
```

That regenerates every Android mipmap and the iOS `AppIcon.appiconset`. Commit
the generated files.

Store listing assets, which are uploaded in the consoles and are not part of the
build:

| Asset | Spec | Store |
| --- | --- | --- |
| App icon | 512×512, 32-bit PNG **with** alpha, ≤1024 KB | Play |
| Feature graphic | 1024×500, JPEG or 24-bit PNG, **no** alpha | Play (mandatory) |
| Phone screenshots | 2–8, min 320 px / max 3840 px per side, and the long side no more than twice the short side; 4 at ≥1080 px recommended | Play |
| App Store icon | 1024×1024 PNG, **no** alpha, no rounded corners of your own | App Store |
| iPhone screenshots | 1–10, no alpha. At least one size: 6.9" is 1320×2868 portrait; 6.3" is 1206×2622; 6.5" is 1284×2778 | App Store |
| iPad screenshots | 13" is 2064×2752 portrait | App Store, **only if the app runs on iPad** |

On that last row: `TARGETED_DEVICE_FAMILY` is currently `"1,2"`, so the app
declares iPad support and Apple will both require iPad screenshots and test the
layout on an iPad. If Swipe Eat is a phone app, set it to `"1"` in
`ios/Runner.xcodeproj/project.pbxproj` (three occurrences) and the iPad
obligation disappears. That is a product call, so it has been left as-is.

Sources for the specs above: [Play graphic assets](https://support.google.com/googleplay/android-developer/answer/9866151),
[App Store screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/).

### 3. The Android upload keystore

Create it once and never lose it — a lost upload key is recoverable through Play
support only if Play App Signing is on, and a lost *app signing* key without
Play App Signing means you can never update the app again.

```bash
keytool -genkey -v \
  -keystore ~/keys/swipe-eat-upload.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
in the four values. That file and `*.jks` are already gitignored — keep them out
of the repo and back the keystore up somewhere you control.

Do not paste the passwords into this chat or into any file inside the repo.

Verify the release build picks the key up:

```bash
flutter build appbundle --release
```

Without `key.properties` the build falls back to the debug key so that
`flutter run --release` keeps working; Play rejects a debug-signed upload, so
check the build log actually mentions the release config.

Get the SHA-1 for the Google OAuth client with:

```bash
keytool -list -v -keystore ~/keys/swipe-eat-upload.jks -alias upload
```

### 4. Build the release artefacts

Both stores need the production dart-defines baked in — a build without
`SENTRY_DSN` reports no crashes, and one without the Google client ids hides the
Google button.

```bash
# Android — upload the .aab, not an apk
flutter build appbundle --release \
  --dart-define=SENTRY_DSN=... \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GOOGLE_IOS_CLIENT_ID=...

# iOS — then archive and upload from Xcode, or with `xcrun altool`
flutter build ipa --release \
  --dart-define=SENTRY_DSN=... \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

The output lands in `build/app/outputs/bundle/release/app-release.aab` and
`build/ios/ipa/`.

### 5. Play Console forms

- **App access** — the whole app is behind a login, so you must give reviewers a
  working test account (email + password). Create one specifically for review;
  do not hand over a real account.
- **Data safety** — declare what the app actually collects. Based on the code
  today: *Name*, *Email address*, *User IDs*, *Approximate location*, *App
  interactions* (likes/passes/saves/visited), and *Crash logs*. All are
  collected, none are shared with third parties for advertising, all are
  encrypted in transit, and users can request deletion — point the form at the
  deletion URL above. This must match the privacy policy and the iOS privacy
  manifest.
- **Privacy policy** — the `/legal/privacy` URL.
- **Content rating** — fill in the questionnaire honestly. Note that the app
  embeds third-party TikTok videos, which is user-generated content you do not
  moderate; answer that section accordingly.
- **Ads** — declare no ads.
- **Target audience** — 13+, matching the privacy policy.
- **Government apps / financial features / health** — none apply.
- **Target API level** — nothing to do. New submissions must target API 36 from
  31 August 2026 and the app already does
  ([policy](https://support.google.com/googleplay/android-developer/answer/11926878),
  [target SDK guide](https://developer.android.com/google/play/requirements/target-sdk)).

### 6. App Store Connect forms

- **App privacy** questionnaire — must match `PrivacyInfo.xcprivacy` exactly:
  email address, name, user id, precise location and product interaction all
  *linked to identity*, crash data *not linked*, and **no tracking** anywhere.
- **Sign in with Apple** — guideline 4.8 requires it when you offer Google
  sign-in. The Dart side is already implemented (`sign_in_with_apple`), but the
  entitlement and the App ID capability are not. See the Xcode step in the first
  section — without it the button fails and the app is rejected.
- **Account deletion** — guideline 5.1.1(v) requires the in-app path that
  Settings → Account now provides. Reviewers look for it, so mention where it is
  in the review notes.
- **Demo account** — same as Play: a review-only login.
- **Location permission** — the purpose string is already in `Info.plist`. Make
  sure the reviewer can see why it is asked for; the app must still work if they
  decline.
- **Export compliance** — answered by `ITSAppUsesNonExemptEncryption`.
- **Age rating** — 13+ / 12+, and disclose the unmoderated third-party video.

### 7. Before you upload

```bash
flutter analyze
flutter test
```

Then on a real device, in a release build:

- Sign up with email, confirm, sign in.
- Google sign-in and Apple sign-in, after the console work in the first section.
- Deny the location permission and confirm the app still opens and swipes.
- Settings → Account → **Delete account**, then confirm the same email can sign
  up again from scratch. This is the flow both stores check.

---

## Outstanding items that are not store blockers

- `SENTRY_DSN` is not set anywhere, so no crash reporting reaches production
  until it is passed as a dart-define.
- Supabase leaked-password protection is still off; turn it on in the dashboard's
  auth settings.
- 474 of 1607 restaurants have no coordinates yet, and only 2 have ratings.
  Neither blocks submission — the app hides the directions button on a missing
  coordinate and shows an em dash for a missing rating — but it does affect how
  the app looks in review.
