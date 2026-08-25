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
  static const String _notificationsEnabledKey = 'profile.notificationsEnabled';
  static const String _soundEnabledKey = 'profile.soundEnabled';
  static const String _hapticsEnabledKey = 'profile.hapticsEnabled';
  static const String _battleMusicVolumeKey = 'profile.battleMusicVolume';

  const SharedPreferencesProfileSettingsStorage();

  @override
  Future<ProfileSettings?> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? displayName = preferences.getString(_displayNameKey);
    final String? targetCode = preferences.getString(_targetKey);
    final bool? notificationsEnabled = preferences.getBool(
      _notificationsEnabledKey,
    );
    final bool? soundEnabled = preferences.getBool(_soundEnabledKey);
    final bool? hapticsEnabled = preferences.getBool(_hapticsEnabledKey);
    final double? battleMusicVolume = preferences.getDouble(
      _battleMusicVolumeKey,
    );

    if (displayName == null &&
        targetCode == null &&
        notificationsEnabled == null &&
        soundEnabled == null &&
        hapticsEnabled == null &&
        battleMusicVolume == null) {
      return null;
    }

    final ProfileSettings fallback = ProfileSettings.initial();
    return ProfileSettings(
      displayName: displayName ?? fallback.displayName,
      target: _targetFromName(targetCode),
      notificationsEnabled:
          notificationsEnabled ?? fallback.notificationsEnabled,
      soundEnabled: soundEnabled ?? fallback.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? fallback.hapticsEnabled,
      battleMusicVolume:
          (battleMusicVolume ?? fallback.battleMusicVolume).clamp(0.0, 1.0),
    );
  }

  @override
  Future<void> save(ProfileSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_displayNameKey, settings.displayName);
    await preferences.setBool(
      _notificationsEnabledKey,
      settings.notificationsEnabled,
    );
    await preferences.setBool(_soundEnabledKey, settings.soundEnabled);
    await preferences.setBool(_hapticsEnabledKey, settings.hapticsEnabled);
    await preferences.setDouble(
      _battleMusicVolumeKey,
      settings.battleMusicVolume.clamp(0.0, 1.0),
    );

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
