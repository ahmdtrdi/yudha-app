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
  }) : _botRepository = botRepository,
       _onlineRepository = onlineRepository,
       super(BattleState.initial()) {
    _onlineUpdatesSubscription = _onlineRepository.updates.listen(
      _handleOnlineUpdate,
    );
  }

  final BattleRepository _botRepository;
  final OnlineBattleRepository _onlineRepository;
  late final StreamSubscription<OnlineBattleUpdate> _onlineUpdatesSubscription;
  bool _acceptOnlineUpdates = false;
  String? _preparedQuestionId;

  void setMode(BattleMode mode) {
    if (state.phase == BattlePhase.inBattle) {
      return;
    }

    _preparedQuestionId = null;
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
      statusMessage: 'Mode ${_modeLabel(mode)} dipilih. Tekan mulai battle.',
      clearErrorMessage: true,
      clearBattleEvent: true,
    );
  }

  void enterArena() {
    if (state.phase == BattlePhase.inBattle || state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
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
      statusMessage: 'Pilih mode arena.',
      clearErrorMessage: true,
      clearBattleEvent: true,
    );
  }

  void exitArena() {
    if (state.phase == BattlePhase.inBattle || state.isLoading) {
      return;
    }

    _acceptOnlineUpdates = false;
    _preparedQuestionId = null;
    state = BattleState.initial().copyWith(mode: state.mode);
  }

  Future<void> startBattle() async {
    if (state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
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
        isLoading: false,
        statusMessage: state.mode == BattleMode.online
            ? 'Lawan ditemukan. Arena dimulai.'
            : 'Battle dimulai.',
        clearErrorMessage: true,
        clearBattleEvent: true,
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

    state = BattleStateMachine.resolveTurn(
      state: state,
      question: question,
      selectedOptionIndex: selectedOptionIndex,
    );
    releasePreparedQuestion(questionId);
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

    state = BattleStateMachine.resolveOpponentTurn(
      state: state,
      question: question,
    );
  }

  Future<void> surrenderBattle() async {
    if (!state.isBattleActive || state.isLoading) {
      return;
    }

    _preparedQuestionId = null;
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
    _onlineUpdatesSubscription.cancel();
    _onlineRepository.dispose();
    super.dispose();
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
        state = state.copyWith(
          phase: update.phase == 'finished'
              ? state.phase
              : BattlePhase.inBattle,
          opponentName: state.opponentName,
          playerHp: update.playerHp,
          opponentHp: update.opponentHp,
          playerPoints: update.playerPoints,
          opponentPoints: update.opponentPoints,
          availableQuestions: update.availableQuestions,
          answeredQuestionIds: update.answeredQuestionIds,
          isLoading: false,
          rewardClaimed: false,
          statusMessage: _statusForOnlinePhase(update.phase),
          clearErrorMessage: true,
        );
        break;
      case CardPlayedUpdate():
        final BattleQuestion? question = _findQuestionById(update.cardId);
        final QuestionEffect? effect = update.effect;
        final bool isCorrect = update.correct;
        state = state.copyWith(
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
        break;
      case MatchResultUpdate():
        _preparedQuestionId = null;
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
}
