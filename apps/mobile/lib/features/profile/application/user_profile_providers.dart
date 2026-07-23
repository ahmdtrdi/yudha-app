import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_controller.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/backend_user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';

final Provider<UserProfileApiConfig> userProfileApiConfigProvider =
    Provider<UserProfileApiConfig>(
      (Ref ref) =>
          UserProfileApiConfig(accessToken: ref.watch(authAccessTokenProvider)),
    );

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>(
      (Ref ref) => BackendUserProfileRepository(
        config: ref.watch(userProfileApiConfigProvider),
      ),
    );

final StateNotifierProvider<UserProfileController, UserProfileState>
userProfileProvider =
    StateNotifierProvider<UserProfileController, UserProfileState>(
      (Ref ref) => UserProfileController(
        repository: ref.watch(userProfileRepositoryProvider),
        shouldHydrate: ref.watch(isAuthenticatedProvider),
        onProfileChanged: (profile) => ref
            .read(profileSettingsProvider.notifier)
            .syncProfile(
              displayName: profile.displayName,
              target: profile.target,
            ),
      ),
    );
