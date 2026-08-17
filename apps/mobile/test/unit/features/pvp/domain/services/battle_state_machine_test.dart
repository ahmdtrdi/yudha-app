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

      expect(resolved.opponentHp, 95);
      expect(resolved.playerPoints, 5);
      expect(resolved.phase, BattlePhase.inBattle);
      expect(resolved.outcome, BattleOutcome.inProgress);
      expect(resolved.answerHistory, hasLength(1));
      expect(resolved.answerHistory.single.questionId, question.id);
      expect(resolved.answerHistory.single.isCorrect, isTrue);
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
        comboLevel: 3,
        availableQuestions: const <BattleQuestion>[healQuestion],
      );

      final BattleState resolved = BattleStateMachine.resolveTurn(
        state: initial,
        question: healQuestion,
        selectedOptionIndex: 1,
      );

      expect(resolved.playerHp, 100);
      expect(resolved.playerPoints, 15);
    });

    test('combo levels apply exactly 5, 10, and 15 effect points', () {
      expect(BattleStateMachine.effectFromCombo(1), 5);
      expect(BattleStateMachine.effectFromCombo(2), 10);
      expect(BattleStateMachine.effectFromCombo(3), 15);
      expect(BattleStateMachine.effectFromCombo(99), 15);
    });

    test('heal uses the same combo-scaled values as damage', () {
      const BattleQuestion healQuestion = BattleQuestion(
        id: 'q-heal-scale',
        prompt: 'Test scaled heal',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 4,
        effect: QuestionEffect.heal,
      );

      for (final int comboLevel in <int>[1, 2, 3]) {
        final BattleState initial = BattleState.initial().copyWith(
          phase: BattlePhase.inBattle,
          playerHp: 50,
          comboLevel: comboLevel,
          availableQuestions: const <BattleQuestion>[healQuestion],
        );
        final BattleState resolved = BattleStateMachine.resolveTurn(
          state: initial,
          question: healQuestion,
          selectedOptionIndex: 0,
        );

        final int expectedHeal = comboLevel * 5;
        expect(resolved.playerHp, 50 + expectedHeal);
        expect(resolved.playerPoints, expectedHeal);
      }
    });

    test('wrong answer replaces only the player card that was used', () {
      const BattleQuestion usedQuestion = BattleQuestion(
        id: 'q-used',
        prompt: 'Used',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 1,
        effect: QuestionEffect.damage,
      );
      const BattleQuestion retainedQuestion = BattleQuestion(
        id: 'q-retained',
        prompt: 'Retained',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 1,
        effect: QuestionEffect.damage,
      );
      final BattleState initial = BattleState.initial().copyWith(
        phase: BattlePhase.inBattle,
        availableQuestions: const <BattleQuestion>[
          usedQuestion,
          retainedQuestion,
        ],
      );

      final BattleState resolved = BattleStateMachine.resolveTurn(
        state: initial,
        question: usedQuestion,
        selectedOptionIndex: 1,
      );

      expect(
        resolved.availableQuestions.map((question) => question.id),
        equals(<String>[retainedQuestion.id]),
      );
      expect(resolved.answeredQuestionIds, contains(usedQuestion.id));
      expect(resolved.answerHistory.single.isCorrect, isFalse);
    });

    test('recycles the final player card while battle remains active', () {
      const BattleQuestion finalQuestion = BattleQuestion(
        id: 'q-final-player',
        prompt: 'Final player question',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 1,
        effect: QuestionEffect.damage,
        category: 'verbal',
      );
      final BattleState initial = BattleState.initial().copyWith(
        phase: BattlePhase.inBattle,
        availableQuestions: const <BattleQuestion>[finalQuestion],
        answeredQuestionIds: const <String>['q-before'],
      );

      final BattleState resolved = BattleStateMachine.resolveTurn(
        state: initial,
        question: finalQuestion,
        selectedOptionIndex: 1,
      );

      expect(resolved.phase, BattlePhase.inBattle);
      expect(resolved.availableQuestions, hasLength(1));
      expect(resolved.availableQuestions.single.prompt, finalQuestion.prompt);
      expect(resolved.availableQuestions.single.id, isNot(finalQuestion.id));
      expect(resolved.answeredQuestionIds, isEmpty);
    });

    test('opponent attack preserves every player card', () {
      const BattleQuestion finalQuestion = BattleQuestion(
        id: 'q-final-bot',
        prompt: 'Final bot question',
        options: <String>['A', 'B'],
        correctOptionIndex: 0,
        weight: 1,
        effect: QuestionEffect.damage,
        category: 'numerik',
      );
      final BattleState initial = BattleState.initial().copyWith(
        phase: BattlePhase.inBattle,
        availableQuestions: const <BattleQuestion>[finalQuestion],
        answeredQuestionIds: const <String>['q-before'],
      );

      final BattleState resolved = BattleStateMachine.resolveOpponentTurn(
        state: initial,
        question: finalQuestion,
      );

      expect(resolved.phase, BattlePhase.inBattle);
      expect(resolved.availableQuestions, same(initial.availableQuestions));
      expect(resolved.availableQuestions.single.id, finalQuestion.id);
      expect(resolved.answeredQuestionIds, initial.answeredQuestionIds);
    });
  });
}
