import 'package:shared_preferences/shared_preferences.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

abstract class ProfileSettingsStorage {
  Future<ProfileSettings?> load();

  Future<void> save(ProfileSettings settings);
}

class SharedPreferencesProfileSettingsStorage
    implements ProfileSettingsStorage {
  static const String _displayNameKey = 'profile.displayName';
  static const String _targetKey = 'profile.target';
  static const String _soundEnabledKey = 'profile.soundEnabled';
  static const String _hapticsEnabledKey = 'profile.hapticsEnabled';

  const SharedPreferencesProfileSettingsStorage();

  @override
  Future<ProfileSettings?> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? displayName = preferences.getString(_displayNameKey);
    final String? targetCode = preferences.getString(_targetKey);
    final bool? soundEnabled = preferences.getBool(_soundEnabledKey);
    final bool? hapticsEnabled = preferences.getBool(_hapticsEnabledKey);

    if (displayName == null &&
        targetCode == null &&
        soundEnabled == null &&
        hapticsEnabled == null) {
      return null;
    }

    final ProfileSettings fallback = ProfileSettings.initial();
    return ProfileSettings(
      displayName: displayName ?? fallback.displayName,
      target: _targetFromName(targetCode),
      soundEnabled: soundEnabled ?? fallback.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? fallback.hapticsEnabled,
    );
  }

  @override
  Future<void> save(ProfileSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_displayNameKey, settings.displayName);
    await preferences.setBool(_soundEnabledKey, settings.soundEnabled);
    await preferences.setBool(_hapticsEnabledKey, settings.hapticsEnabled);

    final ProfileTarget? target = settings.target;
    if (target == null) {
      await preferences.remove(_targetKey);
    } else {
      await preferences.setString(_targetKey, target.name);
    }
  }

  ProfileTarget? _targetFromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final ProfileTarget target in ProfileTarget.values) {
      if (target.name == name) {
        return target;
      }
    }
    return null;
  }
}
