import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

enum UserProfileStatus { initial, loading, ready, saving, error }

class UserProfileState {
  const UserProfileState({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  factory UserProfileState.initial() {
    return const UserProfileState(status: UserProfileStatus.initial);
  }

  final UserProfileStatus status;
  final UserProfile? profile;
  final String? errorMessage;

  UserProfileState copyWith({
    UserProfileStatus? status,
    UserProfile? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
