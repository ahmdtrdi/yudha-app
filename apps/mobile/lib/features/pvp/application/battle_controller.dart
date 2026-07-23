import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

class BattleController extends StateNotifier<BattleState> {
  BattleController({
    required BattleRepository botRepository,
    required OnlineBattleRepository onlineRepository,
    Duration comboTickDuration = const Duration(seconds: 1),
    Duration roundTickDuration = const Duration(seconds: 1),
    int roundDuration = roundDurationSeconds,
  }) : assert(roundDuration > 0),
       _botRepository = botRepository,
       _onlineRepository = onlineRepository,
       _comboTickDuration = comboTickDuration,
       _roundTickDuration = roundTickDuration,
       _roundDurationSeconds = roundDuration,
       super(BattleState.initial()) {
    _onlineUpdatesSubscription = _onlineRepository.updates.listen(
      _handleOnlineUpdate,
    );
  }

  final BattleRepository _botRepository;
  final OnlineBattleRepository _onlineRepository;
  final Duration _comboTickDuration;
  final Duration _roundTickDuration;
  final int _roundDurationSeconds;
  static const int comboWindowSeconds = 7;
  static const int roundDurationSeconds = 180;
  static const int maxRounds = 3;
  static const int winsToWin = 2;
  late final StreamSubscription<OnlineBattleUpdate> _onlineUpdatesSubscription;
  Timer? _comboTimer;
  Timer? _roundTimer;
  bool _roundClockPaused = false;
  bool _acceptOnlineUpdates = false;
  String? _preparedQuestionId;

  void setMode(BattleMode mode) {
    if (state.isMatchActive) {
      return;
    }

    _preparedQuestionId = null;
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
      availableQuestions: const <BattleQuestion>[],
      answeredQuestionIds: const <String>[],
      rewardClaimed: false,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      lastProjectileLevel: 1,
      currentRound: 1,
      playerRoundWins: 0,
      opponentRoundWins: 0,
      roundSecondsRemaining: _roundDurationSeconds,
      statusMessage: 'Mode ${_modeLabel(mode)} dipilih. Tekan mulai battle.',
      clearErrorMessage: true,
      clearBattleEvent: true,
      clearLastRoundOutcome: true,
    );
  }

  void enterArena() {
    if (state.isMatchActive || state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
    _resetBattleTimers();
    state = state.copyWith(
      phase: BattlePhase.arenaMenu,
      outcome: BattleOutcome.inProgress,
      playerHp: 100,
      opponentHp: 100,
      playerPoints: 0,
      opponentPoints: 0,
      ratingDelta: 0,
      availableQuestions: const <BattleQuestion>[],
      answeredQuestionIds: const <String>[],
      rewardClaimed: false,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      lastProjectileLevel: 1,
      currentRound: 1,
      playerRoundWins: 0,
      opponentRoundWins: 0,
      roundSecondsRemaining: _roundDurationSeconds,
      statusMessage: 'Pilih mode arena.',
      clearErrorMessage: true,
      clearBattleEvent: true,
      clearLastRoundOutcome: true,
    );
  }

  void exitArena() {
    if (state.isMatchActive || state.isLoading) {
      return;
    }

    _acceptOnlineUpdates = false;
    _preparedQuestionId = null;
    _resetBattleTimers();
    state = BattleState.initial().copyWith(mode: state.mode);
  }

  Future<void> startBattle() async {
    if (state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
    _resetBattleTimers();
    _acceptOnlineUpdates = state.mode == BattleMode.online;
    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Menyiapkan battle...',
      clearErrorMessage: true,
    );

    try {
      final session = await _activeRepositoryForMode(
        state.mode,
      ).createSession();

      state = state.copyWith(
        phase: BattlePhase.inBattle,
        outcome: BattleOutcome.inProgress,
        opponentName: session.opponentName,
        availableQuestions: session.questions,
        answeredQuestionIds: const <String>[],
        playerHp: 100,
        opponentHp: 100,
        playerPoints: 0,
        opponentPoints: 0,
        ratingDelta: 0,
        rewardClaimed: false,
        comboLevel: 1,
        comboSecondsRemaining: 0,
        lastProjectileLevel: 1,
        currentRound: 1,
        playerRoundWins: 0,
        opponentRoundWins: 0,
        roundSecondsRemaining: _roundDurationSeconds,
        isLoading: false,
        statusMessage: state.mode == BattleMode.online
            ? 'Lawan ditemukan. Arena dimulai.'
            : 'Battle dimulai.',
        clearErrorMessage: true,
        clearBattleEvent: true,
        clearLastRoundOutcome: true,
      );
    } catch (_) {
      _acceptOnlineUpdates = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memulai battle. Coba lagi.',
      );
    }
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

    if (state.mode == BattleMode.online) {
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
          errorMessage: 'Jawaban gagal dikirim ke arena online.',
        );
        return false;
      }
    }

    final bool isCorrect =
        question.correctOptionIndex != null &&
        selectedOptionIndex == question.correctOptionIndex;
    final int projectileLevel = isCorrect ? state.comboLevel : 1;
    final BattleState resolved = BattleStateMachine.resolveTurn(
      state: state,
      question: question,
      selectedOptionIndex: selectedOptionIndex,
    );
    state = isCorrect
        ? _raiseCombo(resolved, projectileLevel: projectileLevel)
        : _lowerCombo(resolved, projectileLevel: projectileLevel);
    releasePreparedQuestion(questionId);
    _completeRoundIfHpDepleted();
    return true;
  }

  void answerBotQuestion() {
    if (!state.isBattleActive ||
        state.isLoading ||
        state.mode != BattleMode.bot) {
      return;
    }

    final BattleQuestion? question = _pickBotQuestion();
    if (question == null) {
      return;
    }

    final BattleState resolved = BattleStateMachine.resolveOpponentTurn(
      state: state,
      question: question,
    );
    state = resolved.playerHp < state.playerHp
        ? _lowerCombo(resolved, projectileLevel: 1)
        : resolved.copyWith(lastProjectileLevel: 1);
    _completeRoundIfHpDepleted();
  }

  /// Starts the three-minute clock after the arena countdown reaches GO.
  ///
  /// During a round break this also resets both fighters to full HP and opens
  /// the next round before starting its clock.
  void beginRound() {
    if (state.phase == BattlePhase.roundBreak) {
      if (state.mode == BattleMode.online) {
        return;
      }
      state = state.copyWith(
        phase: BattlePhase.inBattle,
        currentRound: state.currentRound + 1,
        playerHp: 100,
        opponentHp: 100,
        playerPoints: 0,
        opponentPoints: 0,
        comboLevel: 1,
        comboSecondsRemaining: 0,
        lastProjectileLevel: 1,
        roundSecondsRemaining: _roundDurationSeconds,
        statusMessage: 'Ronde ${state.currentRound + 1} dimulai.',
        clearErrorMessage: true,
        clearBattleEvent: true,
        clearLastRoundOutcome: true,
      );
    }
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
    if (state.mode == BattleMode.online) {
      await _onlineRepository.surrender();
      return;
    }

    state = state.copyWith(
      phase: BattlePhase.finished,
      outcome: BattleOutcome.lose,
      playerHp: 0,
      ratingDelta: -12,
      statusMessage: 'Kamu menyerah.',
      clearErrorMessage: true,
      clearBattleEvent: true,
    );
  }

  void resetBattle() {
    _acceptOnlineUpdates = false;
    _preparedQuestionId = null;
    _resetBattleTimers();
    state = BattleState.initial().copyWith(
      mode: state.mode,
      phase: BattlePhase.arenaMenu,
      opponentName: state.mode == BattleMode.bot ? 'BOT YUDHA' : 'Player Match',
      clearBattleEvent: true,
    );
  }

  Future<bool> prepareQuestion(BattleQuestion question) async {
    if (state.mode == BattleMode.bot) {
      _preparedQuestionId = question.id;
      return true;
    }

    try {
      await _onlineRepository.openCard(cardId: question.id);
      _preparedQuestionId = question.id;
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

  BattleRepository _activeRepositoryForMode(BattleMode mode) {
    return mode == BattleMode.bot ? _botRepository : _onlineRepository;
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
      if (state.mode == BattleMode.online) {
        _resetRoundTimer();
        return;
      }
      _finishRound(_outcomeFromCurrentHp());
      return;
    }
    state = state.copyWith(
      roundSecondsRemaining: state.roundSecondsRemaining - 1,
    );
  }

  void _completeRoundIfHpDepleted() {
    if (!state.isBattleActive || (state.playerHp > 0 && state.opponentHp > 0)) {
      return;
    }
    _finishRound(_outcomeFromCurrentHp());
  }

  BattleOutcome _outcomeFromCurrentHp() {
    if (state.playerHp > state.opponentHp) {
      return BattleOutcome.win;
    }
    if (state.playerHp < state.opponentHp) {
      return BattleOutcome.lose;
    }
    return BattleOutcome.draw;
  }

  void _finishRound(BattleOutcome roundOutcome) {
    if (!state.isBattleActive) {
      return;
    }

    _preparedQuestionId = null;
    _resetComboTimer();
    _resetRoundTimer();

    final int playerRoundWins =
        state.playerRoundWins + (roundOutcome == BattleOutcome.win ? 1 : 0);
    final int opponentRoundWins =
        state.opponentRoundWins + (roundOutcome == BattleOutcome.lose ? 1 : 0);
    final bool matchFinished =
        playerRoundWins >= winsToWin ||
        opponentRoundWins >= winsToWin ||
        state.currentRound >= maxRounds;
    final String roundMessage = _roundResultMessage(roundOutcome);

    if (!matchFinished) {
      state = state.copyWith(
        phase: BattlePhase.roundBreak,
        outcome: BattleOutcome.inProgress,
        playerRoundWins: playerRoundWins,
        opponentRoundWins: opponentRoundWins,
        comboLevel: 1,
        comboSecondsRemaining: 0,
        roundSecondsRemaining: 0,
        lastRoundOutcome: roundOutcome,
        statusMessage:
            '$roundMessage Ronde ${state.currentRound + 1} segera dimulai.',
        clearErrorMessage: true,
      );
      return;
    }

    final BattleOutcome matchOutcome;
    if (playerRoundWins > opponentRoundWins) {
      matchOutcome = BattleOutcome.win;
    } else if (playerRoundWins < opponentRoundWins) {
      matchOutcome = BattleOutcome.lose;
    } else {
      matchOutcome = BattleOutcome.draw;
    }
    _acceptOnlineUpdates = false;
    state = state.copyWith(
      phase: BattlePhase.finished,
      outcome: matchOutcome,
      playerRoundWins: playerRoundWins,
      opponentRoundWins: opponentRoundWins,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      ratingDelta: _ratingDeltaForOutcome(matchOutcome),
      lastRoundOutcome: roundOutcome,
      statusMessage: '$roundMessage ${_matchResultMessage(matchOutcome)}',
      clearErrorMessage: true,
    );
  }

  String _roundResultMessage(BattleOutcome outcome) {
    return switch (outcome) {
      BattleOutcome.win => 'Kamu memenangkan ronde ${state.currentRound}.',
      BattleOutcome.lose =>
        '${state.opponentName} memenangkan ronde ${state.currentRound}.',
      BattleOutcome.draw => 'Ronde ${state.currentRound} berakhir seri.',
      BattleOutcome.inProgress => 'Ronde ${state.currentRound} selesai.',
    };
  }

  String _matchResultMessage(BattleOutcome outcome) {
    return switch (outcome) {
      BattleOutcome.win => 'Kamu memenangkan game!',
      BattleOutcome.lose => '${state.opponentName} memenangkan game.',
      BattleOutcome.draw => 'Game berakhir seri.',
      BattleOutcome.inProgress => '',
    };
  }

  void _handleOnlineUpdate(OnlineBattleUpdate update) {
    if (!_acceptOnlineUpdates) {
      return;
    }
    switch (update) {
      case QueueJoinedUpdate():
        state = state.copyWith(
          isLoading: true,
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
          opponentName: _displayNameForOpponent(update.opponentUserId),
          statusMessage: 'Lawan ditemukan. Menyiapkan arena...',
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
        state = state.copyWith(
          phase: onlinePhase,
          opponentName: state.opponentName,
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
          isLoading: false,
          rewardClaimed: false,
          statusMessage: update.phase == 'round_break'
              ? _onlineRoundResultMessage(update)
              : _statusForOnlinePhase(update.phase),
          clearErrorMessage: true,
          clearLastRoundOutcome: update.lastRoundOutcome == null,
        );
        break;
      case CardPlayedUpdate():
        final BattleQuestion? question = _findQuestionById(update.cardId);
        final QuestionEffect? effect = update.effect;
        final bool isCorrect = update.correct;
        final BattleState eventState = state.copyWith(
          battleEventId: state.battleEventId + 1,
          lastActor: isCorrect ? BattleActor.player : BattleActor.opponent,
          lastVisualEffect: effect == null
              ? null
              : effect == QuestionEffect.heal
              ? BattleVisualEffect.heal
              : BattleStateMachine.visualEffectForCategory(
                  question?.category ?? 'numerik',
                ),
          lastEventCategory: question?.category ?? 'numerik',
          statusMessage: _statusForPlayResult(
            isCorrect: isCorrect,
            effect: effect,
            effectValue: update.effectValue,
          ),
          clearErrorMessage: true,
          clearBattleEvent: effect == null,
        );
        state = isCorrect
            ? _raiseCombo(eventState, projectileLevel: update.projectileLevel)
            : _lowerCombo(eventState, projectileLevel: 1);
        break;
      case MatchResultUpdate():
        _preparedQuestionId = null;
        _resetBattleTimers();
        state = state.copyWith(
          phase: BattlePhase.finished,
          outcome: update.outcome,
          ratingDelta: _ratingDeltaForOutcome(update.outcome),
          isLoading: false,
          statusMessage: _resultMessage(update.outcome, update.reason),
          clearErrorMessage: true,
        );
        break;
      case PresenceUpdated():
        if (!update.opponentConnected) {
          state = state.copyWith(
            statusMessage: 'Lawan terputus. Menunggu hasil akhir arena...',
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

  BattleQuestion? _pickBotQuestion() {
    BattleQuestion? fallback;
    for (final BattleQuestion question in state.availableQuestions) {
      if (question.id == _preparedQuestionId) {
        continue;
      }
      fallback ??= question;
      if (question.effect == QuestionEffect.damage) {
        return question;
      }
    }
    return fallback;
  }

  String _modeLabel(BattleMode mode) {
    return mode == BattleMode.bot ? 'Bot' : 'Online';
  }

  String _statusForOnlinePhase(String phase) {
    return switch (phase) {
      'card_opened' => 'Kartu terbuka. Jawab sekarang.',
      'finished' => state.statusMessage ?? 'Battle selesai.',
      _ => 'Battle online sedang berlangsung.',
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
    required bool isCorrect,
    required QuestionEffect? effect,
    required int effectValue,
  }) {
    if (!isCorrect) {
      return 'Jawaban belum tepat. Arena berpindah ke lawan.';
    }
    if (effect == QuestionEffect.heal) {
      return 'Jawaban benar. HP pulih $effectValue poin.';
    }
    if (effect == QuestionEffect.damage) {
      return 'Jawaban benar. Serangan masuk $effectValue damage.';
    }
    return 'Jawaban diproses arena.';
  }

  int _ratingDeltaForOutcome(BattleOutcome outcome) {
    return switch (outcome) {
      BattleOutcome.win => 20,
      BattleOutcome.lose => -12,
      BattleOutcome.draw || BattleOutcome.inProgress => 0,
    };
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

  String _displayNameForOpponent(String opponentUserId) {
    if (opponentUserId.trim().isEmpty) {
      return 'Player Match';
    }
    final String compact = opponentUserId.replaceAll('-', '');
    final String suffix = compact.length > 6
        ? compact.substring(compact.length - 6).toUpperCase()
        : compact.toUpperCase();
    return 'Player $suffix';
  }

  BattleState _raiseCombo(
    BattleState resolved, {
    required int projectileLevel,
  }) {
    if (!resolved.isBattleActive) {
      _resetComboTimer();
      return resolved.copyWith(
        comboSecondsRemaining: 0,
        lastProjectileLevel: projectileLevel.clamp(1, 3),
      );
    }
    final int nextLevel = (state.comboLevel + 1).clamp(1, 3);
    final BattleState next = resolved.copyWith(
      comboLevel: nextLevel,
      comboSecondsRemaining: comboWindowSeconds,
      lastProjectileLevel: projectileLevel.clamp(1, 3),
    );
    _startComboTimer();
    return next;
  }

  BattleState _lowerCombo(
    BattleState resolved, {
    required int projectileLevel,
  }) {
    if (!resolved.isBattleActive) {
      _resetComboTimer();
      return resolved.copyWith(
        comboSecondsRemaining: 0,
        lastProjectileLevel: projectileLevel.clamp(1, 3),
      );
    }
    final int nextLevel = (state.comboLevel - 1).clamp(1, 3);
    final int remaining = nextLevel > 1 ? comboWindowSeconds : 0;
    final BattleState next = resolved.copyWith(
      comboLevel: nextLevel,
      comboSecondsRemaining: remaining,
      lastProjectileLevel: projectileLevel.clamp(1, 3),
    );
    if (nextLevel > 1) {
      _startComboTimer();
    } else {
      _resetComboTimer();
    }
    return next;
  }

  void _startComboTimer() {
    _comboTimer?.cancel();
    _comboTimer = Timer.periodic(_comboTickDuration, (Timer timer) {
      if (!state.isBattleActive || state.comboLevel <= 1) {
        timer.cancel();
        return;
      }

      if (state.comboSecondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(comboLevel: 1, comboSecondsRemaining: 0);
        return;
      }

      state = state.copyWith(
        comboSecondsRemaining: state.comboSecondsRemaining - 1,
      );
    });
  }

  void _resetComboTimer() {
    _comboTimer?.cancel();
    _comboTimer = null;
  }

  void _resetRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = null;
    _roundClockPaused = false;
  }

  void _resetBattleTimers() {
    _resetComboTimer();
    _resetRoundTimer();
  }
}
