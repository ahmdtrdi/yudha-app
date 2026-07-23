import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';

class _FakeBotRepository extends BattleRepository {
  const _FakeBotRepository(this.seed);

  final BattleSessionSeed seed;

  @override
  Future<BattleSessionSeed> createSession() async => seed;
}

class _FakeOnlineRepository extends OnlineBattleRepository {
  @override
  Stream<OnlineBattleUpdate> get updates =>
      const Stream<OnlineBattleUpdate>.empty();

  @override
  Future<BattleSessionSeed> createSession() async => const BattleSessionSeed(
    opponentName: 'ONLINE TEST',
    questions: <BattleQuestion>[],
  );

  @override
  Future<void> cancelQueue() async {}

  @override
  void dispose() {}

  @override
  Future<void> openCard({required String cardId}) async {}

  @override
  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  }) async {}

  @override
  Future<void> surrender() async {}
}

void main() {
  const BattleQuestion selectedQuestion = BattleQuestion(
    id: 'q-selected',
    prompt: 'Pertanyaan yang sedang dijawab',
    options: <String>['A', 'B'],
    correctOptionIndex: 0,
    weight: 1,
    effect: QuestionEffect.damage,
    category: 'verbal',
  );
  const BattleQuestion botQuestion = BattleQuestion(
    id: 'q-bot',
    prompt: 'Pertanyaan alternatif untuk bot',
    options: <String>['A', 'B'],
    correctOptionIndex: 0,
    weight: 1,
    effect: QuestionEffect.damage,
    category: 'numerik',
  );

  BattleController createController(List<BattleQuestion> questions) {
    return BattleController(
      botRepository: _FakeBotRepository(
        BattleSessionSeed(opponentName: 'BOT TEST', questions: questions),
      ),
      onlineRepository: _FakeOnlineRepository(),
    );
  }

  BattleController createFastComboController(List<BattleQuestion> questions) {
    return BattleController(
      botRepository: _FakeBotRepository(
        BattleSessionSeed(opponentName: 'BOT TEST', questions: questions),
      ),
      onlineRepository: _FakeOnlineRepository(),
      comboTickDuration: const Duration(milliseconds: 5),
    );
  }

  BattleController createFastRoundController(List<BattleQuestion> questions) {
    return BattleController(
      botRepository: _FakeBotRepository(
        BattleSessionSeed(opponentName: 'BOT TEST', questions: questions),
      ),
      onlineRepository: _FakeOnlineRepository(),
      roundTickDuration: const Duration(milliseconds: 5),
      roundDuration: 2,
    );
  }

  group('BattleController question reservation', () {
    test(
      'bot attacks without consuming the selected or alternative card',
      () async {
        final BattleController controller = createController(
          const <BattleQuestion>[selectedQuestion, botQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();

        expect(await controller.prepareQuestion(selectedQuestion), isTrue);
        controller.answerBotQuestion();

        expect(
          controller.state.availableQuestions.map((question) => question.id),
          contains(selectedQuestion.id),
        );
        expect(
          controller.state.availableQuestions.map((question) => question.id),
          contains(botQuestion.id),
        );
        expect(controller.state.availableQuestions, hasLength(2));
        expect(controller.state.playerHp, lessThan(100));
      },
    );

    test('bot waits when the prepared question is the only card', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();

      expect(await controller.prepareQuestion(selectedQuestion), isTrue);
      controller.answerBotQuestion();

      expect(controller.state.playerHp, 100);
      expect(controller.state.battleEventId, 0);
      expect(
        controller.state.availableQuestions.single.id,
        selectedQuestion.id,
      );
    });

    test(
      'releasing a prepared question makes it available to the bot',
      () async {
        final BattleController controller = createController(
          const <BattleQuestion>[selectedQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();
        await controller.prepareQuestion(selectedQuestion);

        controller.releasePreparedQuestion(selectedQuestion.id);
        controller.answerBotQuestion();

        expect(controller.state.playerHp, lessThan(100));
        expect(controller.state.battleEventId, 1);
      },
    );

    test('reset clears the prepared-question reservation', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();
      await controller.prepareQuestion(selectedQuestion);

      controller.resetBattle();
      await controller.startBattle();
      controller.answerBotQuestion();

      expect(controller.state.playerHp, lessThan(100));
      expect(controller.state.battleEventId, 1);
    });
  });

  group('BattleController combo', () {
    test(
      'correct answers raise the next projectile from level 1 to 3',
      () async {
        final BattleController controller = createController(
          const <BattleQuestion>[selectedQuestion, botQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();

        await controller.answerQuestion(
          questionId: selectedQuestion.id,
          selectedOptionIndex: 0,
        );

        expect(controller.state.lastProjectileLevel, 1);
        expect(controller.state.comboLevel, 2);
        expect(
          controller.state.comboSecondsRemaining,
          BattleController.comboWindowSeconds,
        );

        await controller.answerQuestion(
          questionId: botQuestion.id,
          selectedOptionIndex: 0,
        );

        expect(controller.state.lastProjectileLevel, 2);
        expect(controller.state.comboLevel, 3);
      },
    );

    test('a wrong answer lowers one combo level', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion, botQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();
      await controller.answerQuestion(
        questionId: selectedQuestion.id,
        selectedOptionIndex: 0,
      );
      await controller.answerQuestion(
        questionId: botQuestion.id,
        selectedOptionIndex: 0,
      );
      final BattleQuestion recycled = controller.state.availableQuestions.first;

      await controller.answerQuestion(
        questionId: recycled.id,
        selectedOptionIndex: 1,
      );

      expect(controller.state.comboLevel, 2);
    });

    test('taking a hit lowers the combo to level 1', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion, botQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();
      await controller.answerQuestion(
        questionId: selectedQuestion.id,
        selectedOptionIndex: 0,
      );

      controller.answerBotQuestion();

      expect(controller.state.playerHp, lessThan(100));
      expect(controller.state.comboLevel, 1);
      expect(controller.state.comboSecondsRemaining, 0);
    });

    test('combo returns to level 1 when its countdown expires', () async {
      final BattleController controller = createFastComboController(
        const <BattleQuestion>[selectedQuestion, botQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();
      await controller.answerQuestion(
        questionId: selectedQuestion.id,
        selectedOptionIndex: 0,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.comboLevel, 1);
      expect(controller.state.comboSecondsRemaining, 0);
    });
  });

  group('BattleController rounds', () {
    test(
      'a round times out after three minutes and awards higher HP',
      () async {
        final BattleController controller = createFastRoundController(
          const <BattleQuestion>[selectedQuestion, botQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();
        await controller.answerQuestion(
          questionId: selectedQuestion.id,
          selectedOptionIndex: 0,
        );

        controller.beginRound();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.state.roundSecondsRemaining, 0);
        expect(controller.state.phase, BattlePhase.roundBreak);
        expect(controller.state.playerRoundWins, 1);
        expect(controller.state.opponentRoundWins, 0);
      },
    );

    test('first player to win two rounds wins the game', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion, botQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();

      Future<void> winRound() async {
        int safety = 0;
        while (controller.state.opponentHp > 0 && safety < 12) {
          final BattleQuestion question =
              controller.state.availableQuestions.first;
          await controller.answerQuestion(
            questionId: question.id,
            selectedOptionIndex: question.correctOptionIndex!,
          );
          safety += 1;
        }
      }

      await winRound();
      expect(controller.state.phase, BattlePhase.roundBreak);
      expect(controller.state.playerRoundWins, 1);

      controller.beginRound();
      expect(controller.state.currentRound, 2);
      expect(controller.state.playerHp, 100);
      expect(controller.state.opponentHp, 100);

      await winRound();
      expect(controller.state.phase, BattlePhase.finished);
      expect(controller.state.outcome, BattleOutcome.win);
      expect(controller.state.playerRoundWins, 2);
      expect(controller.state.opponentRoundWins, 0);
    });

    test('a game ends after at most three tied rounds', () async {
      final BattleController controller = createFastRoundController(
        const <BattleQuestion>[selectedQuestion, botQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();

      for (int round = 1; round <= 3; round += 1) {
        controller.beginRound();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (round < 3) {
          expect(controller.state.phase, BattlePhase.roundBreak);
        }
      }

      expect(controller.state.currentRound, 3);
      expect(controller.state.phase, BattlePhase.finished);
      expect(controller.state.outcome, BattleOutcome.draw);
      expect(controller.state.playerRoundWins, 0);
      expect(controller.state.opponentRoundWins, 0);
    });
  });
}
