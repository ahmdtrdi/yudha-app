abstract final class AppConfig {
  static const String appName = 'YUDHA';
  static const String apiBaseUrl = String.fromEnvironment(
    'YUDHA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const String gameBaseUrl = String.fromEnvironment(
    'YUDHA_GAME_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;
}
