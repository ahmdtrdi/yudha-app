import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_controller.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_state.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/backend_leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/mock_leaderboard_repository.dart';

final Provider<LeaderboardApiConfig> leaderboardApiConfigProvider =
    Provider<LeaderboardApiConfig>(
      (Ref ref) =>
          LeaderboardApiConfig(accessToken: ref.watch(authAccessTokenProvider)),
    );

final Provider<LeaderboardRepository> leaderboardRepositoryProvider =
    Provider<LeaderboardRepository>(
      (Ref ref) => BackendLeaderboardRepository(
        config: ref.watch(leaderboardApiConfigProvider),
        fallbackRepository: const MockLeaderboardRepository(),
      ),
    );

final StateNotifierProvider<LeaderboardController, LeaderboardState>
leaderboardControllerProvider =
    StateNotifierProvider<LeaderboardController, LeaderboardState>(
      (Ref ref) => LeaderboardController(
        repository: ref.watch(leaderboardRepositoryProvider),
        currentProgress: ref.watch(playerProgressProvider),
      ),
    );
