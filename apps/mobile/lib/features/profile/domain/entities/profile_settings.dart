import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileSettings {
  const ProfileSettings({
    required this.displayName,
    required this.target,
    required this.soundEnabled,
    required this.hapticsEnabled,
  });

  factory ProfileSettings.initial() {
    return const ProfileSettings(
      displayName: '',
      target: null,
      soundEnabled: true,
      hapticsEnabled: true,
    );
  }

  final String displayName;
  final ProfileTarget? target;
  final bool soundEnabled;
  final bool hapticsEnabled;

  bool get isProfileComplete => displayName.trim().isNotEmpty && target != null;

  ProfileSettings copyWith({
    String? displayName,
    ProfileTarget? target,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return ProfileSettings(
      displayName: displayName ?? this.displayName,
      target: target ?? this.target,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}
