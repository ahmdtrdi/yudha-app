import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/bot_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/socket_online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';

final Provider<BattleRepository> botBattleRepositoryProvider =
    Provider<BattleRepository>((Ref ref) => const BotBattleRepository());

final Provider<OnlineBattleRepository> onlineBattleRepositoryProvider =
    Provider<OnlineBattleRepository>(
      (Ref ref) => SocketOnlineBattleRepository(
        accessToken: ref.watch(authAccessTokenProvider),
      ),
    );

final StateNotifierProvider<BattleController, BattleState>
battleControllerProvider = StateNotifierProvider<BattleController, BattleState>(
  (Ref ref) => BattleController(
    botRepository: ref.watch(botBattleRepositoryProvider),
    onlineRepository: ref.watch(onlineBattleRepositoryProvider),
  ),
);
