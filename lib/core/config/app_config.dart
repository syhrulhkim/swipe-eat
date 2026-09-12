class AppConfig {
  const AppConfig._();

  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Swipe Eat');

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vpcldlhqpvunnuexecgn.supabase.co',
  );

  // Publishable key; safe to ship — RLS is the security boundary.
  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_1omniagj5KKjXdHafC28nQ_uvS28WMO',
  );

  /// Google OAuth client ids, from the Google Cloud console. Both are needed
  /// for a native sign-in: the platform id identifies the app to the sheet,
  /// and the *web* id is the audience Supabase validates the returned token
  /// against. They are intentionally not defaulted — an empty value hides the
  /// Google button instead of failing at tap time.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get hasGoogleSignIn => googleWebClientId.isNotEmpty;

  /// Whether the build offers phone (SMS) sign-in.
  ///
  /// Off by default and gated exactly like Google, for the same reason: phone
  /// auth needs an SMS provider (Twilio, MessageBird, …) enabled in the
  /// Supabase dashboard, which is out-of-repo setup with a real per-message
  /// cost. Until that is done the button hides itself rather than failing at
  /// tap time — see docs/Features/Auth.md.
  static const bool phoneAuthEnabled =
      bool.fromEnvironment('PHONE_AUTH_ENABLED');

  /// Whether the sign-up screen offers "Later" — browsing without an account.
  ///
  /// Needs the anonymous provider enabled on the project, which it is not, so
  /// the escape hatch stays hidden instead of signing nobody in.
  static const bool guestBrowsingEnabled =
      bool.fromEnvironment('GUEST_BROWSING_ENABLED');

  /// Firebase, for push. Five values off the console's app registration —
  /// there is no `google-services.json` or `GoogleService-Info.plist` in this
  /// repo, and no gradle plugin: the options are handed to `Firebase
  /// .initializeApp` explicitly, so a build made without them has no Firebase
  /// at all rather than a half-configured one.
  static const String firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');

  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');

  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  static const String firebaseSenderId =
      String.fromEnvironment('FIREBASE_SENDER_ID');

  /// iOS only, and not part of [hasPush]: an Android build has no bundle id to
  /// pass and would be refused push for want of a value it cannot have.
  static const String firebaseIosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Whether this build can be pushed to. False for every test and every local
  /// run, which is what keeps the whole feature inert until the owner has done
  /// the console setup (D155) — the same shape as [hasGoogleSignIn].
  static bool get hasPush =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty;

  /// Sentry's ingest URL for this project. Not defaulted: a build made without
  /// it — every local run and every test — reports nothing at all rather than
  /// filling a project with noise from developer machines.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Which deployment the reports came from, so a staging crash is not read as
  /// a production one.
  static const String sentryEnvironment =
      String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');

  static bool get hasCrashReporting => sentryDsn.isNotEmpty;

  /// Where the public legal pages live. Both stores require a privacy policy
  /// URL, and Google Play additionally requires a data-deletion URL that opens
  /// without installing the app — see `supabase/functions/legal`. Overridable so
  /// a custom domain can front the same pages later without a code change.
  static const String legalBaseUrl = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: '$supabaseUrl/functions/v1/legal',
  );

  static String get privacyPolicyUrl => '$legalBaseUrl/privacy';

  static String get termsUrl => '$legalBaseUrl/terms';

  static String get accountDeletionUrl => '$legalBaseUrl/delete-account';
}
