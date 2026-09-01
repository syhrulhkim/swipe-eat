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
