import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

final Provider<GameEconomyStorage> gameEconomyStorageProvider =
    Provider<GameEconomyStorage>(
      (Ref ref) => const SharedPreferencesGameEconomyStorage(),
    );

final StateNotifierProvider<GameEconomyController, GameEconomyState>
gameEconomyProvider =
    StateNotifierProvider<GameEconomyController, GameEconomyState>(
      (Ref ref) =>
          GameEconomyController(storage: ref.watch(gameEconomyStorageProvider)),
    );
