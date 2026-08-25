import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.displayName,
    required this.target,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.hapticsEnabled,
    this.battleMusicVolume = defaultBattleMusicVolume,
  });

  /// Normalized arena music level (0..1). Intentionally low by default so
  /// battle SFX stay dominant.
  static const double defaultBattleMusicVolume = 0.3;

  factory ProfileSettings.initial() {
    return const ProfileSettings(
      displayName: '',
      target: null,
      notificationsEnabled: true,
      soundEnabled: true,
      hapticsEnabled: true,
    );
  }

  final String displayName;
  final ProfileTarget? target;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final double battleMusicVolume;

  bool get isProfileComplete => displayName.trim().isNotEmpty && target != null;

  ProfileSettings copyWith({
    String? displayName,
    ProfileTarget? target,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
    double? battleMusicVolume,
  }) {
    return ProfileSettings(
      displayName: displayName ?? this.displayName,
      target: target ?? this.target,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      battleMusicVolume:
          battleMusicVolume ?? this.battleMusicVolume,
    );
  }
}
