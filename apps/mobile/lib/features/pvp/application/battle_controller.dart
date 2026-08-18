import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_answer_record.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

class BattleController extends StateNotifier<BattleState> {
  BattleController({
    required OnlineBattleRepository onlineRepository,
    Duration roundTickDuration = const Duration(seconds: 1),
    int roundDuration = roundDurationSeconds,
  }) : assert(roundDuration > 0),
       _onlineRepository = onlineRepository,
       _roundTickDuration = roundTickDuration,
       _roundDurationSeconds = roundDuration,
       super(BattleState.initial()) {
    _onlineUpdatesSubscription = _onlineRepository.updates.listen(
      _handleOnlineUpdate,
    );
  }

  final OnlineBattleRepository _onlineRepository;
  final Duration _roundTickDuration;
  final int _roundDurationSeconds;
  static const int roundDurationSeconds = 180;
  static const int maxRounds = 3;
  static const int winsToWin = 2;
  late final StreamSubscription<OnlineBattleUpdate> _onlineUpdatesSubscription;
  Timer? _roundTimer;
  bool _roundClockPaused = false;
  bool _acceptOnlineUpdates = false;
  bool _matchmakingCancelled = false;
  String? _preparedQuestionId;
  final Map<String, BattleQuestion> _onlineQuestionSnapshots =
      <String, BattleQuestion>{};

  Future<void> reconnectIfActive() async {
    try {
      await _onlineRepository.reconnectIfActive();
    } catch (_) {
      // Ignored if offline or server is unavailable.
    }
  }

  void setMode(BattleMode mode) {
    if (state.isMatchActive) {
      return;
    }

    _preparedQuestionId = null;
    _onlineQuestionSnapshots.clear();
    _resetBattleTimers();
    state = state.copyWith(
      mode: mode,
      phase: state.phase == BattlePhase.arenaMenu
          ? BattlePhase.arenaMenu
          : BattlePhase.preBattle,
      outcome: BattleOutcome.inProgress,
      opponentName: mode == BattleMode.bot ? 'BOT YUDHA' : 'Player Match',
      playerHp: 100,
      opponentHp: 100,
      playerPoints: 0,
      opponentPoints: 0,
      ratingDelta: 0,
      coinsDelta: 0,
      availableQuestions: const <BattleQuestion>[],
      answeredQuestionIds: const <String>[],
      answerHistory: const <BattleAnswerRecord>[],
      rewardClaimed: false,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      lastProjectileLevel: 1,
      currentRound: 1,
      playerRoundWins: 0,
      opponentRoundWins: 0,
      roundSecondsRemaining: _roundDurationSeconds,
      progressionPersisted: false,
      opponentConnected: true,
      statusMessage: 'Mode ${_modeLabel(mode)} dipilih. Tekan mulai battle.',
      clearErrorMessage: true,
      clearBattleEvent: true,
      clearLastRoundOutcome: true,
      clearBattleTarget: true,
      clearPlayerLoadout: true,
      clearOpponentLoadout: true,
      clearReconnectDeadline: true,
    );
  }

  void setOnlineMatchmakingMode(OnlineMatchmakingMode mode) {
    if (state.isMatchActive || state.isLoading) {
      return;
    }
    state = state.copyWith(
      onlineMatchmakingMode: mode,
      statusMessage:
          'Mode ${mode == OnlineMatchmakingMode.bot ? 'Bot' : mode == OnlineMatchmakingMode.ranked ? 'Ranked' : 'Casual'} dipilih.',
      clearErrorMessage: true,
    );
  }

  void enterArena() {
    if (state.isMatchActive || state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
    _onlineQuestionSnapshots.clear();
    _resetBattleTimers();
    state = state.copyWith(
      phase: BattlePhase.arenaMenu,
      outcome: BattleOutcome.inProgress,
      playerHp: 100,
      opponentHp: 100,
      playerPoints: 0,
      opponentPoints: 0,
      ratingDelta: 0,
      coinsDelta: 0,
      availableQuestions: const <BattleQuestion>[],
      answeredQuestionIds: const <String>[],
      answerHistory: const <BattleAnswerRecord>[],
      rewardClaimed: false,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      lastProjectileLevel: 1,
      currentRound: 1,
      playerRoundWins: 0,
      opponentRoundWins: 0,
      roundSecondsRemaining: _roundDurationSeconds,
      progressionPersisted: false,
      opponentConnected: true,
      statusMessage: 'Pilih mode arena.',
      clearErrorMessage: true,
      clearBattleEvent: true,
      clearLastRoundOutcome: true,
      clearBattleTarget: true,
      clearPlayerLoadout: true,
      clearOpponentLoadout: true,
      clearReconnectDeadline: true,
    );
  }

  void exitArena() {
    if (state.isMatchActive || state.isLoading) {
      return;
    }

    _acceptOnlineUpdates = false;
    _preparedQuestionId = null;
    _onlineQuestionSnapshots.clear();
    _resetBattleTimers();
    state = BattleState.initial().copyWith(
      mode: state.mode,
      onlineMatchmakingMode: state.onlineMatchmakingMode,
    );
  }

  Future<void> startBattle() async {
    if (state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
    _resetBattleTimers();
    _matchmakingCancelled = false;
    _acceptOnlineUpdates = true;
    final bool isBot = state.onlineMatchmakingMode == OnlineMatchmakingMode.bot;
    state = state.copyWith(
      isLoading: true,
      statusMessage: isBot ? 'Menyiapkan arena bot...' : 'Mencari lawan...',
      clearErrorMessage: true,
    );

    try {
      final session = await _onlineRepository.createSession(
        matchmakingMode: state.onlineMatchmakingMode,
      );

      state = state.copyWith(
        phase: BattlePhase.inBattle,
        outcome: BattleOutcome.inProgress,
        opponentName: _firstName(
          session.opponentName,
          fallback: isBot ? 'BOT YUDHA' : 'Player Match',
        ),
        availableQuestions: session.questions,
        answeredQuestionIds: const <String>[],
        answerHistory: const <BattleAnswerRecord>[],
        playerHp: 100,
        opponentHp: 100,
        playerPoints: 0,
        opponentPoints: 0,
        ratingDelta: 0,
        coinsDelta: 0,
        rewardClaimed: false,
        comboLevel: 1,
        comboSecondsRemaining: 0,
        lastProjectileLevel: 1,
        currentRound: 1,
        playerRoundWins: 0,
        opponentRoundWins: 0,
        roundSecondsRemaining: _roundDurationSeconds,
        isLoading: false,
        progressionPersisted: false,
        opponentConnected: true,
        statusMessage: isBot
            ? 'Battle bot dimulai.'
            : 'Lawan ditemukan. Arena dimulai.',
        clearErrorMessage: true,
        clearBattleEvent: true,
        clearLastRoundOutcome: true,
      );
    } catch (error) {
      _acceptOnlineUpdates = false;
      if (_matchmakingCancelled) {
        _matchmakingCancelled = false;
        return;
      }
      state = state.copyWith(
        isLoading: false,
        phase: BattlePhase.arenaMenu,
        errorMessage: _battleStartError(error),
      );
    }
  }

  Future<void> cancelMatchmaking() async {
    if (!state.isLoading) {
      return;
    }
    _matchmakingCancelled = true;
    _acceptOnlineUpdates = false;
    await _onlineRepository.cancelQueue();
    state = state.copyWith(
      phase: BattlePhase.arenaMenu,
      isLoading: false,
      statusMessage: 'Pencarian lawan dibatalkan.',
      clearErrorMessage: true,
    );
  }

  Future<bool> answerQuestion({
    required String questionId,
    required int selectedOptionIndex,
  }) async {
    if (!state.isBattleActive || state.isLoading) {
      return false;
    }

    final BattleQuestion? question = _findQuestionById(questionId);
    if (question == null) {
      return false;
    }

    if (selectedOptionIndex < 0) {
      state = state.copyWith(
        statusMessage: 'Pilih satu jawaban untuk mengirim kartu ke arena.',
      );
      return false;
    }

    try {
      await _onlineRepository.submitAnswer(
        cardId: questionId,
        selectedOptionIndex: selectedOptionIndex,
      );
      releasePreparedQuestion(questionId);
      state = state.copyWith(
        statusMessage: 'Jawaban dikirim. Menunggu hasil arena...',
        clearErrorMessage: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Jawaban gagal dikirim ke arena.',
      );
      return false;
    }
  }

  void beginRound() {
    if (!state.isBattleActive || _roundTimer?.isActive == true) {
      return;
    }
    _roundClockPaused = false;
    _roundTimer = Timer.periodic(_roundTickDuration, _tickRoundClock);
  }

  void pauseRoundClock() {
    if (!state.isMatchActive) {
      return;
    }
    _roundClockPaused = true;
  }

  void resumeRoundClock() {
    if (!state.isMatchActive) {
      return;
    }
    _roundClockPaused = false;
  }

  void stopRoundClock() {
    _resetRoundTimer();
  }

  Future<void> surrenderBattle() async {
    if (!state.isBattleActive || state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
    _resetBattleTimers();
    _acceptOnlineUpdates = false;
    resetBattle();
    try {
      await _onlineRepository.surrender();
    } catch (_) {}
  }

  void resetBattle() {
    _acceptOnlineUpdates = false;
    _preparedQuestionId = null;
    _onlineQuestionSnapshots.clear();
    _resetBattleTimers();
    state = BattleState.initial().copyWith(
      mode: state.mode,
      onlineMatchmakingMode: state.onlineMatchmakingMode,
      phase: BattlePhase.arenaMenu,
      opponentName: state.onlineMatchmakingMode == OnlineMatchmakingMode.bot
          ? 'BOT YUDHA'
          : 'Player Match',
      clearBattleEvent: true,
    );
  }

  Future<bool> prepareQuestion(BattleQuestion question) async {
    try {
      await _onlineRepository.openCard(cardId: question.id);
      _preparedQuestionId = question.id;
      _onlineQuestionSnapshots[question.id] = question;
      state = state.copyWith(
        statusMessage: 'Kartu arena dibuka. Jawab sekarang.',
        clearErrorMessage: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Kartu arena belum bisa dibuka. Coba lagi.',
      );
      return false;
    }
  }

  void releasePreparedQuestion(String questionId) {
    if (_preparedQuestionId == questionId) {
      _preparedQuestionId = null;
    }
  }

  void markRewardClaimed() {
    if (!state.isBattleFinished || state.rewardClaimed) {
      return;
    }

    state = state.copyWith(rewardClaimed: true);
  }

  @override
  void dispose() {
    _resetBattleTimers();
    _onlineUpdatesSubscription.cancel();
    _onlineRepository.dispose();
    super.dispose();
  }

  void _tickRoundClock(Timer timer) {
    if (!state.isBattleActive) {
      timer.cancel();
      if (identical(_roundTimer, timer)) {
        _roundTimer = null;
      }
      return;
    }
    if (_roundClockPaused) {
      return;
    }
    if (state.roundSecondsRemaining <= 1) {
      state = state.copyWith(roundSecondsRemaining: 0);
      _resetRoundTimer();
      return;
    }
    state = state.copyWith(
      roundSecondsRemaining: state.roundSecondsRemaining - 1,
    );
  }

  void _handleOnlineUpdate(OnlineBattleUpdate update) {
    if (!_acceptOnlineUpdates) {
      if (update is! GameStateUpdated) {
        return;
      }
      _acceptOnlineUpdates = true;
      state = state.copyWith(
        isLoading: true,
        statusMessage: 'Memulihkan battle online...',
        clearErrorMessage: true,
      );
    }
    switch (update) {
      case QueueJoinedUpdate():
        state = state.copyWith(
          isLoading: true,
          onlineMatchmakingMode: update.matchmakingMode,
          battleTarget: update.target,
          statusMessage:
              'Mencari lawan... posisi ${update.position} dari ${update.queueDepth}.',
          clearErrorMessage: true,
        );
        break;
      case QueueCancelledUpdate():
        state = state.copyWith(
          isLoading: false,
          statusMessage: 'Pencarian lawan dibatalkan.',
          clearErrorMessage: true,
        );
        break;
      case MatchFoundUpdate():
        state = state.copyWith(
          opponentName: _firstName(
            update.opponentDisplayName,
            fallback: update.matchmakingMode == OnlineMatchmakingMode.bot
                ? 'BOT YUDHA'
                : 'Player Match',
          ),
          opponentCharacterId: update.opponentCharacterId,
          opponentTowerId: update.opponentTowerId,
          onlineMatchmakingMode: update.matchmakingMode,
          battleTarget: update.target,
          statusMessage: update.matchmakingMode == OnlineMatchmakingMode.bot
              ? 'Arena bot siap.'
              : 'Lawan ditemukan. Menyiapkan arena...',
          clearErrorMessage: true,
        );
        break;
      case GameStateUpdated():
        final BattlePhase onlinePhase = switch (update.phase) {
          'round_break' => BattlePhase.roundBreak,
          'finished' => state.phase,
          _ => BattlePhase.inBattle,
        };
        if (onlinePhase == BattlePhase.roundBreak) {
          _resetBattleTimers();
        }
        if (_preparedQuestionId != null &&
            !update.availableQuestions.any(
              (question) => question.id == _preparedQuestionId,
            )) {
          _preparedQuestionId = null;
        }
        state = state.copyWith(
          phase: onlinePhase,
          opponentName: _firstName(
            update.opponentDisplayName,
            fallback: update.matchmakingMode == OnlineMatchmakingMode.bot
                ? 'BOT YUDHA'
                : 'Player Match',
          ),
          playerHp: update.playerHp,
          opponentHp: update.opponentHp,
          playerPoints: update.playerPoints,
          opponentPoints: update.opponentPoints,
          comboLevel: update.playerComboLevel,
          currentRound: update.currentRound,
          roundSecondsRemaining: update.roundSecondsRemaining,
          playerRoundWins: update.playerRoundWins,
          opponentRoundWins: update.opponentRoundWins,
          lastRoundOutcome: update.lastRoundOutcome,
          availableQuestions: update.availableQuestions,
          answeredQuestionIds: update.answeredQuestionIds,
          playerCharacterId: update.playerCharacterId,
          playerTowerId: update.playerTowerId,
          opponentCharacterId: update.opponentCharacterId,
          opponentTowerId: update.opponentTowerId,
          onlineMatchmakingMode: update.matchmakingMode,
          battleTarget: update.target,
          opponentConnected: update.opponentConnected,
          isLoading: false,
          rewardClaimed: false,
          statusMessage: update.phase == 'round_break'
              ? _onlineRoundResultMessage(update)
              : _statusForOnlinePhase(update.phase),
          clearErrorMessage: true,
          clearLastRoundOutcome: update.lastRoundOutcome == null,
          clearReconnectDeadline: update.opponentConnected,
        );
        break;
      case CardPlayedUpdate():
        final BattleQuestion? question = update.isSelfAction
            ? _onlineQuestionSnapshots.remove(update.cardId) ??
                  _findQuestionById(update.cardId)
            : _findQuestionById(update.cardId);
        final QuestionEffect? effect = update.effect;
        final bool isCorrect = update.correct;
        state = state.copyWith(
          battleEventId: state.battleEventId + 1,
          lastActor: update.isSelfAction
              ? BattleActor.player
              : BattleActor.opponent,
          lastVisualEffect: effect == null
              ? null
              : effect == QuestionEffect.heal
              ? BattleVisualEffect.heal
              : BattleStateMachine.visualEffectForCategory(
                  update.category ?? question?.category ?? 'numerik',
                ),
          lastEventCategory: update.category ?? question?.category ?? 'numerik',
          statusMessage: _statusForPlayResult(
            isSelfAction: update.isSelfAction,
            isCorrect: isCorrect,
            effect: effect,
            effectValue: update.effectValue,
          ),
          clearErrorMessage: true,
          clearBattleEvent: effect == null,
          lastProjectileLevel: update.projectileLevel,
          answerHistory: update.isSelfAction
              ? <BattleAnswerRecord>[
                  ...state.answerHistory,
                  BattleAnswerRecord(
                    questionId: update.cardId,
                    prompt: question?.prompt ?? '',
                    category:
                        update.category ?? question?.category ?? 'numerik',
                    isCorrect: isCorrect,
                  ),
                ]
              : state.answerHistory,
        );
        break;
      case MatchResultUpdate():
        _acceptOnlineUpdates = false;
        _preparedQuestionId = null;
        _onlineQuestionSnapshots.clear();
        _resetBattleTimers();
        state = state.copyWith(
          phase: BattlePhase.finished,
          outcome: update.outcome,
          ratingDelta: update.ratingDelta,
          coinsDelta: update.coinsDelta,
          progressionPersisted: update.progressionPersisted,
          onlineMatchmakingMode: update.matchmakingMode,
          battleTarget: update.target,
          isLoading: false,
          statusMessage: _resultMessage(update.outcome, update.reason),
          clearErrorMessage: true,
        );
        break;
      case PresenceUpdated():
        if (!update.opponentConnected) {
          state = state.copyWith(
            opponentConnected: false,
            opponentReconnectDeadline: update.opponentReconnectDeadline,
            statusMessage:
                'Lawan terputus. Menunggu reconnect hingga 30 detik...',
          );
        } else {
          state = state.copyWith(
            opponentConnected: true,
            statusMessage: 'Lawan kembali terhubung.',
            clearReconnectDeadline: true,
          );
        }
        break;
      case BattleErrorUpdate():
        state = state.copyWith(isLoading: false, errorMessage: update.message);
        break;
    }
  }

  BattleQuestion? _findQuestionById(String questionId) {
    for (final BattleQuestion question in state.availableQuestions) {
      if (question.id == questionId) {
        return question;
      }
    }
    return null;
  }

  String _modeLabel(BattleMode mode) {
    return mode == BattleMode.bot ? 'Bot' : 'Online';
  }

  String _firstName(String value, {required String fallback}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.split(RegExp(r'\s+')).first;
  }

  String _statusForOnlinePhase(String phase) {
    return switch (phase) {
      'card_opened' => 'Kartu terbuka. Jawab sekarang.',
      'finished' => state.statusMessage ?? 'Battle selesai.',
      _ => 'Battle sedang berlangsung.',
    };
  }

  String _onlineRoundResultMessage(GameStateUpdated update) {
    return switch (update.lastRoundOutcome) {
      BattleOutcome.win =>
        'Kamu memenangkan ronde ${update.currentRound}. '
            'Ronde berikutnya segera dimulai.',
      BattleOutcome.lose =>
        '${state.opponentName} memenangkan ronde ${update.currentRound}. '
            'Ronde berikutnya segera dimulai.',
      BattleOutcome.draw =>
        'Ronde ${update.currentRound} berakhir seri. '
            'Ronde berikutnya segera dimulai.',
      BattleOutcome.inProgress || null =>
        'Ronde ${update.currentRound} selesai. '
            'Ronde berikutnya segera dimulai.',
    };
  }

  String _statusForPlayResult({
    required bool isSelfAction,
    required bool isCorrect,
    required QuestionEffect? effect,
    required int effectValue,
  }) {
    if (!isCorrect) {
      return isSelfAction
          ? 'Jawaban belum tepat.'
          : '${state.opponentName} belum menjawab dengan tepat.';
    }
    if (effect == QuestionEffect.heal) {
      return isSelfAction
          ? 'Jawaban benar. HP pulih $effectValue poin.'
          : '${state.opponentName} memulihkan $effectValue HP.';
    }
    if (effect == QuestionEffect.damage) {
      return isSelfAction
          ? 'Jawaban benar. Serangan masuk $effectValue damage.'
          : '${state.opponentName} menyerang $effectValue damage.';
    }
    return 'Jawaban diproses arena.';
  }

  String _resultMessage(BattleOutcome outcome, String reason) {
    final String outcomeLabel = switch (outcome) {
      BattleOutcome.win => 'Kamu menang.',
      BattleOutcome.lose => 'Kamu kalah.',
      BattleOutcome.draw => 'Hasil seri.',
      BattleOutcome.inProgress => 'Battle belum selesai.',
    };
    if (reason == 'surrender') {
      return '$outcomeLabel Match berakhir karena surrender.';
    }
    return outcomeLabel;
  }

  String _battleStartError(Object error) {
    if (error is TimeoutException) {
      return error.message ?? 'Matchmaking sedang sibuk.';
    }
    if (error is StateError && error.message.toString().trim().isNotEmpty) {
      return error.message.toString();
    }
    return 'Gagal memulai battle. Coba lagi.';
  }

  void _resetRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = null;
    _roundClockPaused = false;
  }

  void _resetBattleTimers() {
    _resetRoundTimer();
  }
}
