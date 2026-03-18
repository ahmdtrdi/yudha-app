import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

void main() {
  group('BattleStateMachine', () {
    test('applies damage on correct answer', () {
      const BattleQuestion question = BattleQuestion(
        id: 'q-dmg',
        prompt: 'Test damage',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 2,
        effect: QuestionEffect.damage,
      );

      final BattleState initial = BattleState.initial().copyWith(
        phase: BattlePhase.inBattle,
        availableQuestions: const <BattleQuestion>[question],
      );

      final BattleState resolved = BattleStateMachine.resolveTurn(
        state: initial,
        question: question,
        selectedOptionIndex: 0,
      );

      expect(resolved.opponentHp, 80);
      expect(resolved.playerPoints, 20);
      expect(resolved.phase, BattlePhase.finished);
      expect(resolved.outcome, BattleOutcome.win);
    });

    test('caps heal at 100 when answer is correct', () {
      const BattleQuestion healQuestion = BattleQuestion(
        id: 'q-heal',
        prompt: 'Test heal',
        options: <String>['A', 'B'],
        correctOptionIndex: 1,
        weight: 3,
        effect: QuestionEffect.heal,
      );

      final BattleState initial = BattleState.initial().copyWith(
        phase: BattlePhase.inBattle,
        playerHp: 95,
        availableQuestions: const <BattleQuestion>[healQuestion],
      );

      final BattleState resolved = BattleStateMachine.resolveTurn(
        state: initial,
        question: healQuestion,
        selectedOptionIndex: 1,
      );

      expect(resolved.playerHp, 100);
      expect(resolved.playerPoints, greaterThan(0));
    });

    test('weight impacts damage amount correctly', () {
      const BattleQuestion lowWeight = BattleQuestion(
        id: 'q-low',
        prompt: 'Low',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 1,
        effect: QuestionEffect.damage,
      );
      const BattleQuestion highWeight = BattleQuestion(
        id: 'q-high',
        prompt: 'High',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 3,
        effect: QuestionEffect.damage,
      );

      expect(
        BattleStateMachine.impactFromWeight(highWeight.weight),
        greaterThan(BattleStateMachine.impactFromWeight(lowWeight.weight)),
      );
    });
  });
}
