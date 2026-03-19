import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

class BattleController extends StateNotifier<BattleState> {
  BattleController({
    required BattleRepository botRepository,
    required BattleRepository onlineRepository,
  }) : _botRepository = botRepository,
       _onlineRepository = onlineRepository,
       super(BattleState.initial());

  final BattleRepository _botRepository;
  final BattleRepository _onlineRepository;

  void setMode(BattleMode mode) {
    if (state.phase == BattlePhase.inBattle) {
      return;
    }

    state = state.copyWith(
      mode: mode,
      phase: BattlePhase.preBattle,
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
    );
  }

  Future<void> startBattle() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Menyiapkan battle...',
      clearErrorMessage: true,
    );

    try {
      final BattleRepository repository = _activeRepositoryForMode(state.mode);
      final session = await repository.createSession();

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
        statusMessage: 'Battle dimulai. Pilih soal untuk damage atau heal.',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memulai battle. Coba lagi.',
      );
    }
  }

  void answerQuestion({
    required String questionId,
    required int selectedOptionIndex,
  }) {
    if (!state.isBattleActive || state.isLoading) {
      return;
    }

    final BattleQuestion? question = _findQuestionById(questionId);
    if (question == null) {
      return;
    }

    state = BattleStateMachine.resolveTurn(
      state: state,
      question: question,
      selectedOptionIndex: selectedOptionIndex,
    );
  }

  void resetBattle() {
    state = BattleState.initial().copyWith(
      mode: state.mode,
      opponentName: state.mode == BattleMode.bot ? 'BOT YUDHA' : 'Player Match',
    );
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
}
