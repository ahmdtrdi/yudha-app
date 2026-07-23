import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

class UserProfileController extends StateNotifier<UserProfileState> {
  UserProfileController({
    required UserProfileRepository repository,
    bool shouldHydrate = false,
    void Function(UserProfile profile)? onProfileChanged,
  }) : _repository = repository,
       _onProfileChanged = onProfileChanged,
       super(UserProfileState.initial()) {
    if (shouldHydrate) {
      unawaited(load());
    }
  }

  final UserProfileRepository _repository;
  final void Function(UserProfile profile)? _onProfileChanged;

  Future<void> load() async {
    state = state.copyWith(status: UserProfileStatus.loading, clearError: true);
    try {
      final UserProfile profile = await _repository.fetchProfile();
      state = state.copyWith(
        status: UserProfileStatus.ready,
        profile: profile,
        clearError: true,
      );
      _onProfileChanged?.call(profile);
    } catch (error) {
      state = state.copyWith(
        status: UserProfileStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<UserProfile?> save(UserProfileUpdate update) async {
    if (state.status == UserProfileStatus.saving) {
      return null;
    }
    state = state.copyWith(status: UserProfileStatus.saving, clearError: true);
    try {
      final UserProfile profile = await _repository.updateProfile(update);
      state = state.copyWith(
        status: UserProfileStatus.ready,
        profile: profile,
        clearError: true,
      );
      _onProfileChanged?.call(profile);
      return profile;
    } catch (error) {
      state = state.copyWith(
        status: UserProfileStatus.ready,
        errorMessage: error.toString(),
      );
      return null;
    }
  }
}
