import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/repositories/backend_game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

final Provider<GameEconomyStorage> gameEconomyStorageProvider =
    Provider<GameEconomyStorage>(
      (Ref ref) => const SharedPreferencesGameEconomyStorage(),
    );

final Provider<GameEconomyRepository?> gameEconomyRepositoryProvider =
    Provider<GameEconomyRepository?>((Ref ref) {
      final String? accessToken = ref.watch(authAccessTokenProvider);
      if (accessToken == null || accessToken.trim().isEmpty) {
        return null;
      }
      final BackendGameEconomyRepository repository =
          BackendGameEconomyRepository(accessToken: accessToken);
      ref.onDispose(repository.dispose);
      return repository;
    });

final StateNotifierProvider<GameEconomyController, GameEconomyState>
gameEconomyProvider =
    StateNotifierProvider<GameEconomyController, GameEconomyState>(
      (Ref ref) => GameEconomyController(
        storage: ref.watch(gameEconomyStorageProvider),
        repository: ref.watch(gameEconomyRepositoryProvider),
      ),
    );
