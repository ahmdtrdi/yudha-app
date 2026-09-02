import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

class UserProfileUpdate {
  const UserProfileUpdate({
    required this.username,
    required this.fullName,
    required this.target,
  });

  final String username;
  final String fullName;
  final ProfileTarget target;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'username': username.trim(),
      'fullName': fullName.trim(),
      'target': target.name,
    };
  }
}

abstract class UserProfileRepository {
  const UserProfileRepository();

  Future<UserProfile> fetchProfile();

  Future<UserProfile> updateProfile(UserProfileUpdate update);

  Future<UserProfile> deleteAccountData();

  Future<void> deleteAccount();
}
