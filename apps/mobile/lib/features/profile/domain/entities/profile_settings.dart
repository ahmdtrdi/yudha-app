import 'package:yudha_mobile/features/profile/domain/entities/profile_language.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.language,
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.hapticsEnabled,
  });

  factory ProfileSettings.initial() {
    return const ProfileSettings(
      language: ProfileLanguage.id,
      notificationsEnabled: true,
      soundEnabled: true,
      hapticsEnabled: true,
    );
  }

  final ProfileLanguage language;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;

  ProfileSettings copyWith({
    ProfileLanguage? language,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return ProfileSettings(
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

