import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/bot_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';

final Provider<BattleRepository> botBattleRepositoryProvider =
    Provider<BattleRepository>((Ref ref) => const BotBattleRepository());

final Provider<BattleRepository> onlineBattleRepositoryProvider =
    Provider<BattleRepository>((Ref ref) => const OnlineBattleRepository());

final StateNotifierProvider<BattleController, BattleState>
battleControllerProvider = StateNotifierProvider<BattleController, BattleState>(
  (Ref ref) => BattleController(
    botRepository: ref.watch(botBattleRepositoryProvider),
    onlineRepository: ref.watch(onlineBattleRepositoryProvider),
  ),
);
