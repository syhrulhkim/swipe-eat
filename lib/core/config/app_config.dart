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
}
