import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';

abstract class OnlineBattleRepository extends BattleRepository {
  const OnlineBattleRepository();

  Stream<OnlineBattleUpdate> get updates;

  Future<void> reconnectIfActive() async {}

  @override
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  });

  Future<void> openCard({required String cardId});

  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  });

  Future<void> cancelQueue();

  Future<void> surrender();

  void dispose();
}
