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

  /// The map's raster tile template, and the credit drawn over it.
  ///
  /// The default is OpenStreetMap's public server, which their tile usage
  /// policy allows for development and **forbids for a released app**: they
  /// may cut a heavy client off without notice, and a store build that points
  /// here can go blank overnight. Shipping means an account with a tile host
  /// (MapTiler, Stadia, Mapbox, Thunderforest, or a self-hosted renderer) and
  /// two defines, so the swap is a build flag rather than a code change:
  ///
  ///   --dart-define=MAP_TILE_URL_TEMPLATE=https://…/{z}/{x}/{y}.png?key=…
  ///   --dart-define=MAP_TILE_ATTRIBUTION='© MapTiler © OpenStreetMap'
  ///
  /// The credit travels with the template because every host requires its own,
  /// and a template swapped without its attribution is a licence breach.
  static const String mapTileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL_TEMPLATE',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String mapTileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap',
  );

  /// True when the build is still pointing at OSM's public server, which is
  /// the one thing standing between this app and a store release.
  static bool get usesDevelopmentTiles =>
      mapTileUrlTemplate.contains('tile.openstreetmap.org');

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
