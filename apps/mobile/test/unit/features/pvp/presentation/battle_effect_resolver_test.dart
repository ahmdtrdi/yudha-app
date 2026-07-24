import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page/battle_effect_resolver.dart';

void main() {
  group('resolveBattleEffectActor', () {
    test('opponent damage to the player always starts from opponent', () {
      expect(
        resolveBattleEffectActor(playerDelta: -14, opponentDelta: 0),
        BattleActor.opponent,
      );
    });

    test('player damage to the opponent always starts from player', () {
      expect(
        resolveBattleEffectActor(playerDelta: 0, opponentDelta: -14),
        BattleActor.player,
      );
    });

    test('healing starts from the side whose HP increases', () {
      expect(
        resolveBattleEffectActor(playerDelta: 14, opponentDelta: 0),
        BattleActor.player,
      );
      expect(
        resolveBattleEffectActor(playerDelta: 0, opponentDelta: 14),
        BattleActor.opponent,
      );
    });
  });
}
