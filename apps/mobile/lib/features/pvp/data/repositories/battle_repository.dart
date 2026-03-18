import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';

abstract class BattleRepository {
  const BattleRepository();

  Future<BattleSessionSeed> createSession();
}
