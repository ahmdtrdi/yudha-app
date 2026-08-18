import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

void main() {
  group('BattleStateMachine', () {
    test('combo levels apply exactly 5, 10, and 15 effect points', () {
      expect(BattleStateMachine.effectFromCombo(1), 5);
      expect(BattleStateMachine.effectFromCombo(2), 10);
      expect(BattleStateMachine.effectFromCombo(3), 15);
      expect(BattleStateMachine.effectFromCombo(99), 15);
    });

    test('visualEffectForCategory maps categories to visual effects', () {
      expect(
        BattleStateMachine.visualEffectForCategory('verbal'),
        BattleVisualEffect.wizard,
      );
      expect(
        BattleStateMachine.visualEffectForCategory('logika'),
        BattleVisualEffect.robot,
      );
      expect(
        BattleStateMachine.visualEffectForCategory('twk'),
        BattleVisualEffect.heal,
      );
      expect(
        BattleStateMachine.visualEffectForCategory('numerik'),
        BattleVisualEffect.cannon,
      );
    });

    test('attackLabel returns appropriate weapon names', () {
      expect(BattleStateMachine.attackLabel('verbal'), 'Wizard Bolt');
      expect(BattleStateMachine.attackLabel('logika'), 'Robot Slam');
      expect(BattleStateMachine.attackLabel('numerik'), 'Cannon Strike');
      expect(BattleStateMachine.attackLabel('unknown'), 'Serangan');
    });
  });
}
