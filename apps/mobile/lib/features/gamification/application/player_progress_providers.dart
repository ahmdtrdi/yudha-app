import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/backend_player_progress_repository.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';

final Provider<PlayerProgressApiConfig> playerProgressApiConfigProvider =
    Provider<PlayerProgressApiConfig>(
      (Ref ref) => PlayerProgressApiConfig(
        accessToken: ref.watch(authAccessTokenProvider),
      ),
    );

final Provider<PlayerProgressRepository> playerProgressRepositoryProvider =
    Provider<PlayerProgressRepository>(
      (Ref ref) => BackendPlayerProgressRepository(
        config: ref.watch(playerProgressApiConfigProvider),
      ),
    );

final StateNotifierProvider<PlayerProgressController, PlayerProgress>
playerProgressProvider =
    StateNotifierProvider<PlayerProgressController, PlayerProgress>(
      (Ref ref) => PlayerProgressController(
        repository: ref.watch(playerProgressRepositoryProvider),
        shouldHydrate: ref.watch(isAuthenticatedProvider),
        onDisplayNameHydrated: ref
            .read(profileSettingsProvider.notifier)
            .syncDisplayName,
      ),
    );
