import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/config/app_config.dart';

abstract final class AppAuthStorage {
  static final SharedPreferencesLocalStorage
  instance = SharedPreferencesLocalStorage(
    persistSessionKey:
        'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token',
  );
}
