import 'package:yudha_mobile/features/profile/domain/entities/profile_language.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.displayName,
    required this.target,
    required this.language,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.hapticsEnabled,
  });

  factory ProfileSettings.initial() {
    return const ProfileSettings(
      displayName: '',
      target: null,
      language: ProfileLanguage.id,
      notificationsEnabled: true,
      soundEnabled: true,
      hapticsEnabled: true,
    );
  }

  final String displayName;
  final ProfileTarget? target;
  final ProfileLanguage language;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;

  bool get isProfileComplete =>
      displayName.trim().isNotEmpty && target != null;

  ProfileSettings copyWith({
    String? displayName,
    ProfileTarget? target,
    ProfileLanguage? language,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return ProfileSettings(
      displayName: displayName ?? this.displayName,
      target: target ?? this.target,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}
