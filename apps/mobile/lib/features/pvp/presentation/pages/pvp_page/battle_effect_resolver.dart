import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

BattleActor resolveBattleEffectActor({
  required int playerDelta,
  required int opponentDelta,
}) {
  if (playerDelta == 0 && opponentDelta == 0) {
    throw ArgumentError('At least one HP delta must be non-zero.');
  }

  final bool targetsPlayer = playerDelta != 0;
  final int delta = targetsPlayer ? playerDelta : opponentDelta;
  final bool isHeal = delta > 0;

  if (isHeal) {
    return targetsPlayer ? BattleActor.player : BattleActor.opponent;
  }
  return targetsPlayer ? BattleActor.opponent : BattleActor.player;
}
