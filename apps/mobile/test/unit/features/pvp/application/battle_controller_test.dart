import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';

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
  int cancelQueueCount = 0;
  String? lastOpenedCardId;
  String? lastSubmittedCardId;
  int? lastSubmittedOptionIndex;

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
  Future<void> cancelQueue() async {
    cancelQueueCount += 1;
  }

  @override
  void dispose() {
    _updates.close();
  }

  @override
  Future<void> openCard({required String cardId}) async {
    lastOpenedCardId = cardId;
  }

  @override
  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  }) async {
    lastSubmittedCardId = cardId;
    lastSubmittedOptionIndex = selectedOptionIndex;
  }

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
  const BattleQuestion secondQuestion = BattleQuestion(
    id: 'q-second',
    prompt: 'Pertanyaan alternatif',
    options: <String>['A', 'B'],
    correctOptionIndex: 0,
    weight: 1,
    effect: QuestionEffect.damage,
    category: 'numerik',
  );

  group('BattleController mode and matchmaking selection', () {
    test('enters and exits arena resetting state appropriately', () {
      final _FakeOnlineRepository repository = _FakeOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: repository,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      expect(controller.state.phase, BattlePhase.arenaMenu);
      expect(controller.state.statusMessage, 'Pilih mode arena.');

      controller.setOnlineMatchmakingMode(OnlineMatchmakingMode.bot);
      expect(controller.state.onlineMatchmakingMode, OnlineMatchmakingMode.bot);
      expect(controller.state.statusMessage, 'Mode Bot dipilih.');

      controller.exitArena();
      expect(controller.state.phase, BattlePhase.preBattle);
      expect(controller.state.onlineMatchmakingMode, OnlineMatchmakingMode.bot);
    });

    test('starts bot match requesting OnlineMatchmakingMode.bot', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      controller.setOnlineMatchmakingMode(OnlineMatchmakingMode.bot);
      await controller.startBattle();

      expect(online.requestedMode, OnlineMatchmakingMode.bot);
      expect(controller.state.phase, BattlePhase.inBattle);
      expect(controller.state.opponentName, 'SERVER');
      expect(controller.state.availableQuestions, hasLength(1));
    });

    test('cancels matchmaking when queue is in progress', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      controller.setOnlineMatchmakingMode(OnlineMatchmakingMode.ranked);
      final Future<void> startFuture = controller.startBattle();
      expect(controller.state.isLoading, isTrue);

      await controller.cancelMatchmaking();
      expect(online.cancelQueueCount, 1);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.phase, BattlePhase.arenaMenu);

      await startFuture;
    });
  });

  group('BattleController question handling', () {
    test('prepareQuestion calls openCard on online repository', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      await controller.startBattle();

      final bool success = await controller.prepareQuestion(selectedQuestion);
      expect(success, isTrue);
      expect(online.lastOpenedCardId, selectedQuestion.id);
    });

    test('answerQuestion calls submitAnswer on online repository', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      await controller.startBattle();
      online.emit(
        const GameStateUpdated(
          roomId: 'room-1',
          phase: 'active',
          playerHp: 100,
          opponentHp: 100,
          playerPoints: 0,
          opponentPoints: 0,
          playerComboLevel: 1,
          currentRound: 1,
          roundSecondsRemaining: 180,
          playerRoundWins: 0,
          opponentRoundWins: 0,
          lastRoundOutcome: null,
          availableQuestions: <BattleQuestion>[
            selectedQuestion,
            secondQuestion,
          ],
          answeredQuestionIds: <String>[],
          playerDisplayName: 'Yudha',
          opponentDisplayName: 'BOT YUDHA',
        ),
      );

      await controller.prepareQuestion(selectedQuestion);
      final bool success = await controller.answerQuestion(
        questionId: selectedQuestion.id,
        selectedOptionIndex: 0,
      );

      expect(success, isTrue);
      expect(online.lastSubmittedCardId, selectedQuestion.id);
      expect(online.lastSubmittedOptionIndex, 0);
    });
  });

  group('BattleController authoritative online state', () {
    test('keeps the player card details for online answer analysis', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      controller.setMode(BattleMode.online);
      await controller.startBattle();
      await controller.prepareQuestion(selectedQuestion);
      expect(controller.state.selfAnswerResultId, 0);
      expect(controller.state.lastSelfAnswerCorrect, isNull);

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
      expect(controller.state.selfAnswerResultId, 1);
      expect(controller.state.lastSelfAnswerCorrect, isFalse);
    });

    test('restores an active server room after controller recreation', () {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
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

      expect(controller.state.phase, BattlePhase.inBattle);
      expect(controller.state.opponentName, 'Bima');
      expect(controller.state.playerHp, 80);
    });

    test('uses ranked queue choice and server-owned result metadata', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
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
      expect(controller.state.selfAnswerResultId, 0);
      expect(controller.state.lastSelfAnswerCorrect, isNull);

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

    test(
      'handles presence updates when opponent disconnects and reconnects',
      () async {
        final _ControllableOnlineRepository online =
            _ControllableOnlineRepository();
        final BattleController controller = BattleController(
          onlineRepository: online,
        );
        addTearDown(controller.dispose);

        controller.enterArena();
        await controller.startBattle();

        online.emit(
          PresenceUpdated(
            opponentConnected: false,
            opponentReconnectDeadline: DateTime.now().add(
              const Duration(seconds: 30),
            ),
          ),
        );

        expect(controller.state.opponentConnected, isFalse);
        expect(controller.state.opponentReconnectDeadline, isNotNull);

        online.emit(
          const PresenceUpdated(
            opponentConnected: true,
            opponentReconnectDeadline: null,
          ),
        );

        expect(controller.state.opponentConnected, isTrue);
        expect(controller.state.opponentReconnectDeadline, isNull);
      },
    );
  });

  group('BattleController round clock and rewards', () {
    test('round timer ticks countdown when battle active', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
        roundTickDuration: const Duration(milliseconds: 10),
        roundDuration: 5,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      await controller.startBattle();

      controller.beginRound();
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(controller.state.roundSecondsRemaining, lessThan(5));

      controller.pauseRoundClock();
      final int pausedTime = controller.state.roundSecondsRemaining;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(controller.state.roundSecondsRemaining, pausedTime);

      controller.resumeRoundClock();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(
        controller.state.roundSecondsRemaining,
        lessThanOrEqualTo(pausedTime),
      );
    });

    test('marks reward claimed when battle is finished', () async {
      final _ControllableOnlineRepository online =
          _ControllableOnlineRepository();
      final BattleController controller = BattleController(
        onlineRepository: online,
      );
      addTearDown(controller.dispose);

      controller.enterArena();
      await controller.startBattle();

      online.emit(
        const MatchResultUpdate(
          outcome: BattleOutcome.win,
          reason: 'opponent_hp_zero',
          ratingDelta: 15,
          coinsDelta: 50,
          progressionPersisted: true,
        ),
      );

      expect(controller.state.phase, BattlePhase.finished);
      expect(controller.state.rewardClaimed, isFalse);

      controller.markRewardClaimed();
      expect(controller.state.rewardClaimed, isTrue);
    });
  });
}
