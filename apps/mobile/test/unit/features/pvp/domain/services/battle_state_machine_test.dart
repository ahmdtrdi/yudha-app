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
      expect(resolved.phase, BattlePhase.inBattle);
      expect(resolved.outcome, BattleOutcome.inProgress);
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
