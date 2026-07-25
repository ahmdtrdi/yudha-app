import 'dart:async';

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
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  }) async => const BattleSessionSeed(
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

class _ControllableOnlineRepository extends OnlineBattleRepository {
  final StreamController<OnlineBattleUpdate> _updates =
      StreamController<OnlineBattleUpdate>.broadcast(sync: true);

  OnlineMatchmakingMode? requestedMode;
  int surrenderCount = 0;

  @override
  Stream<OnlineBattleUpdate> get updates => _updates.stream;

  void emit(OnlineBattleUpdate update) => _updates.add(update);

  @override
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  }) async {
    requestedMode = matchmakingMode;
    return const BattleSessionSeed(
      opponentName: 'SERVER OPPONENT',
      questions: <BattleQuestion>[
        BattleQuestion(
          id: 'q-online',
          prompt: 'Online question',
          options: <String>['A', 'B'],
          weight: 1,
          effect: QuestionEffect.damage,
        ),
      ],
    );
  }

  @override
  Future<void> cancelQueue() async {}

  @override
  void dispose() {
    _updates.close();
  }

  @override
  Future<void> openCard({required String cardId}) async {}

  @override
  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  }) async {}

  @override
  Future<void> surrender() async {
    surrenderCount += 1;
  }
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

  group('BattleController authoritative online state', () {
    test('keeps the player card details for online answer analysis', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        botRepository: const _FakeBotRepository(
          BattleSessionSeed(
            opponentName: 'BOT TEST',
            questions: <BattleQuestion>[selectedQuestion],
          ),
        ),
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      controller.setMode(BattleMode.online);
      await controller.startBattle();
      await controller.prepareQuestion(selectedQuestion);

      online.emit(
        const GameStateUpdated(
          roomId: 'room-answer-analysis',
          phase: 'active',
          playerHp: 95,
          opponentHp: 100,
          playerPoints: 0,
          opponentPoints: 5,
          playerComboLevel: 1,
          currentRound: 1,
          roundSecondsRemaining: 170,
          playerRoundWins: 0,
          opponentRoundWins: 0,
          lastRoundOutcome: null,
          availableQuestions: <BattleQuestion>[],
          answeredQuestionIds: <String>['q-selected'],
          playerDisplayName: 'Yudha',
          opponentDisplayName: 'Bima',
        ),
      );
      online.emit(
        const CardPlayedUpdate(
          cardId: 'q-selected',
          correct: false,
          effect: QuestionEffect.damage,
          effectValue: 5,
          projectileLevel: 1,
          isSelfAction: true,
          category: 'verbal',
        ),
      );

      expect(controller.state.answerHistory, hasLength(1));
      expect(
        controller.state.answerHistory.single.prompt,
        selectedQuestion.prompt,
      );
      expect(controller.state.answerHistory.single.category, 'verbal');
      expect(controller.state.answerHistory.single.isCorrect, isFalse);
    });

    test('restores an active server room after controller recreation', () {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        botRepository: const _FakeBotRepository(
          BattleSessionSeed(
            opponentName: 'BOT TEST',
            questions: <BattleQuestion>[selectedQuestion],
          ),
        ),
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      online.emit(
        const GameStateUpdated(
          roomId: 'room-restored',
          phase: 'active',
          playerHp: 80,
          opponentHp: 65,
          playerPoints: 20,
          opponentPoints: 10,
          playerComboLevel: 2,
          currentRound: 2,
          roundSecondsRemaining: 90,
          playerRoundWins: 1,
          opponentRoundWins: 0,
          lastRoundOutcome: BattleOutcome.win,
          availableQuestions: <BattleQuestion>[selectedQuestion],
          answeredQuestionIds: <String>[],
          playerDisplayName: 'Yudha',
          opponentDisplayName: 'Bima Pratama',
          matchmakingMode: OnlineMatchmakingMode.ranked,
          target: BattleTarget.cpns,
        ),
      );

      expect(controller.state.mode, BattleMode.online);
      expect(controller.state.phase, BattlePhase.inBattle);
      expect(controller.state.opponentName, 'Bima');
      expect(controller.state.playerHp, 80);
    });

    test('uses ranked queue choice and server-owned result metadata', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        botRepository: const _FakeBotRepository(
          BattleSessionSeed(
            opponentName: 'BOT TEST',
            questions: <BattleQuestion>[selectedQuestion],
          ),
        ),
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      controller.setMode(BattleMode.online);
      controller.setOnlineMatchmakingMode(OnlineMatchmakingMode.ranked);
      await controller.startBattle();

      expect(online.requestedMode, OnlineMatchmakingMode.ranked);

      online.emit(
        const GameStateUpdated(
          roomId: 'room-1',
          phase: 'active',
          playerHp: 90,
          opponentHp: 75,
          playerPoints: 15,
          opponentPoints: 5,
          playerComboLevel: 2,
          currentRound: 2,
          roundSecondsRemaining: 121,
          playerRoundWins: 1,
          opponentRoundWins: 0,
          lastRoundOutcome: BattleOutcome.win,
          availableQuestions: <BattleQuestion>[selectedQuestion],
          answeredQuestionIds: <String>['card-old'],
          playerDisplayName: 'Yudha',
          opponentDisplayName: 'Bima',
          playerCharacterId: 'character-basic-squire',
          playerTowerId: 'tower-garda-biru',
          opponentCharacterId: 'character-basic-pip',
          opponentTowerId: 'tower-benteng-bara',
          matchmakingMode: OnlineMatchmakingMode.ranked,
          target: BattleTarget.bumn,
        ),
      );

      expect(controller.state.opponentName, 'Bima');
      expect(controller.state.battleTarget, BattleTarget.bumn);
      expect(controller.state.opponentCharacterId, 'character-basic-pip');
      expect(controller.state.opponentTowerId, 'tower-benteng-bara');
      expect(controller.state.playerHp, 90);

      online.emit(
        const CardPlayedUpdate(
          cardId: 'server-card',
          correct: true,
          effect: QuestionEffect.damage,
          effectValue: 10,
          projectileLevel: 2,
          isSelfAction: false,
          category: 'verbal',
        ),
      );
      expect(controller.state.lastActor, BattleActor.opponent);
      expect(controller.state.lastEventCategory, 'verbal');
      expect(controller.state.lastVisualEffect, BattleVisualEffect.wizard);

      online.emit(
        const MatchResultUpdate(
          outcome: BattleOutcome.lose,
          reason: 'hp_zero',
          ratingDelta: -12,
          coinsDelta: 3,
          progressionPersisted: true,
          matchmakingMode: OnlineMatchmakingMode.ranked,
          target: BattleTarget.bumn,
        ),
      );

      expect(controller.state.phase, BattlePhase.finished);
      expect(controller.state.ratingDelta, -12);
      expect(controller.state.coinsDelta, 3);
      expect(controller.state.progressionPersisted, isTrue);
    });

    test(
      'surrender returns directly to mode selection and ignores result UI',
      () async {
        final _ControllableOnlineRepository online =
            _ControllableOnlineRepository();
        final BattleController controller = BattleController(
          botRepository: const _FakeBotRepository(
            BattleSessionSeed(
              opponentName: 'BOT TEST',
              questions: <BattleQuestion>[selectedQuestion],
            ),
          ),
          onlineRepository: online,
        );
        addTearDown(controller.dispose);

        controller.enterArena();
        controller.setMode(BattleMode.online);
        await controller.startBattle();
        expect(controller.state.phase, BattlePhase.inBattle);

        await controller.surrenderBattle();
        expect(online.surrenderCount, 1);
        expect(controller.state.phase, BattlePhase.arenaMenu);

        online.emit(
          const MatchResultUpdate(
            outcome: BattleOutcome.lose,
            reason: 'surrender',
            ratingDelta: 0,
            coinsDelta: 0,
            progressionPersisted: true,
          ),
        );
        expect(controller.state.phase, BattlePhase.arenaMenu);
      },
    );
  });
}
