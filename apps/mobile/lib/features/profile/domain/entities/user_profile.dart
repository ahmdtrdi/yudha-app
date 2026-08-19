import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.target,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString().trim() ?? '',
      fullName:
          (json['fullName'] ?? json['full_name'])?.toString().trim() ?? '',
      target: _targetFromValue(json['target']),
    );
  }

  final String id;
  final String username;
  final String fullName;
  final ProfileTarget target;

  String get displayName {
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (username.isNotEmpty) {
      return username;
    }
    return 'Kamu';
  }

  static ProfileTarget _targetFromValue(Object? value) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == ProfileTarget.bumn.name
        ? ProfileTarget.bumn
        : ProfileTarget.cpns;
  }
}
