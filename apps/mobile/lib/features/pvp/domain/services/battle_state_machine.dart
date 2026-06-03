import 'dart:math';

import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';

abstract final class BattleStateMachine {
  static BattleState resolveTurn({
    required BattleState state,
    required BattleQuestion question,
    required int selectedOptionIndex,
  }) {
    final bool isCorrect = selectedOptionIndex == question.correctOptionIndex;
    final int impact = impactFromWeight(question.weight);

    int playerHp = state.playerHp;
    int opponentHp = state.opponentHp;
    int playerPoints = state.playerPoints;
    int opponentPoints = state.opponentPoints;

    late final String statusMessage;

    if (question.effect == QuestionEffect.damage) {
      if (isCorrect) {
        opponentHp -= impact;
        playerPoints += impact;
        statusMessage =
            '${_attackLabel(question.category)} masuk. Musuh menerima $impact damage.';
      } else {
        final int reflectedDamage = max(1, impact ~/ 2);
        playerHp -= reflectedDamage;
        opponentPoints += reflectedDamage;
        statusMessage =
            'Jawaban kurang tepat. Kamu menerima $reflectedDamage damage.';
      }
    } else {
      if (isCorrect) {
        playerHp += impact;
        playerPoints += max(1, impact ~/ 2);
        statusMessage = 'TWK Heal aktif. Kamu memulihkan HP sebesar $impact.';
      } else {
        final int opponentHeal = max(1, impact ~/ 2);
        opponentHp += opponentHeal;
        opponentPoints += opponentHeal;
        statusMessage =
            'Jawaban kurang tepat. Musuh memulihkan HP $opponentHeal.';
      }
    }

    playerHp = _clampHp(playerHp);
    opponentHp = _clampHp(opponentHp);

    final List<BattleQuestion> remainingQuestions = state.availableQuestions
        .where((BattleQuestion item) => item.id != question.id)
        .toList(growable: false);

    final List<String> answeredQuestions = <String>[
      ...state.answeredQuestionIds,
      question.id,
    ];

    final ({BattlePhase phase, BattleOutcome outcome, int ratingDelta}) finish =
        _resolvePhase(
          playerHp: playerHp,
          opponentHp: opponentHp,
          playerPoints: playerPoints,
          opponentPoints: opponentPoints,
          hasRemainingQuestions: remainingQuestions.isNotEmpty,
        );

    return state.copyWith(
      phase: finish.phase,
      outcome: finish.outcome,
      ratingDelta: finish.ratingDelta,
      playerHp: playerHp,
      opponentHp: opponentHp,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      availableQuestions: remainingQuestions,
      answeredQuestionIds: answeredQuestions,
      battleEventId: state.battleEventId + 1,
      lastActor: _actorForPlayerTurn(question: question, isCorrect: isCorrect),
      lastVisualEffect: _visualEffectForTurn(
        question: question,
        isCorrect: isCorrect,
      ),
      lastEventCategory: question.category,
      statusMessage: finish.phase == BattlePhase.finished
          ? '$statusMessage ${_resultLabel(finish.outcome)}'
          : statusMessage,
      clearErrorMessage: true,
    );
  }

  static BattleState resolveOpponentTurn({
    required BattleState state,
    required BattleQuestion question,
  }) {
    final int impact = impactFromWeight(question.weight);

    int playerHp = state.playerHp;
    int opponentHp = state.opponentHp;
    final int playerPoints = state.playerPoints;
    int opponentPoints = state.opponentPoints;

    late final String statusMessage;

    if (question.effect == QuestionEffect.heal) {
      opponentHp += impact;
      opponentPoints += max(1, impact ~/ 2);
      statusMessage = 'BOT YUDHA menjawab TWK. Musuh memulihkan HP $impact.';
    } else {
      playerHp -= impact;
      opponentPoints += impact;
      statusMessage = 'BOT YUDHA menjawab benar. Kamu menerima $impact damage.';
    }

    playerHp = _clampHp(playerHp);
    opponentHp = _clampHp(opponentHp);

    final List<BattleQuestion> remainingQuestions = state.availableQuestions
        .where((BattleQuestion item) => item.id != question.id)
        .toList(growable: false);

    final ({BattlePhase phase, BattleOutcome outcome, int ratingDelta}) finish =
        _resolvePhase(
          playerHp: playerHp,
          opponentHp: opponentHp,
          playerPoints: playerPoints,
          opponentPoints: opponentPoints,
          hasRemainingQuestions: remainingQuestions.isNotEmpty,
        );

    return state.copyWith(
      phase: finish.phase,
      outcome: finish.outcome,
      ratingDelta: finish.ratingDelta,
      playerHp: playerHp,
      opponentHp: opponentHp,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      availableQuestions: remainingQuestions,
      answeredQuestionIds: <String>[
        ...state.answeredQuestionIds,
        'bot:${question.id}',
      ],
      battleEventId: state.battleEventId + 1,
      lastActor: BattleActor.opponent,
      lastVisualEffect: question.effect == QuestionEffect.heal
          ? BattleVisualEffect.heal
          : visualEffectForCategory(question.category),
      lastEventCategory: question.category,
      statusMessage: finish.phase == BattlePhase.finished
          ? '$statusMessage ${_resultLabel(finish.outcome)}'
          : statusMessage,
      clearErrorMessage: true,
    );
  }

  static int impactFromWeight(int weight) {
    final int boundedWeight = weight.clamp(1, 4);
    return 8 + (boundedWeight * 6);
  }

  static BattleVisualEffect visualEffectForCategory(String category) {
    return switch (category.toLowerCase()) {
      'verbal' => BattleVisualEffect.wizard,
      'logika' => BattleVisualEffect.robot,
      'twk' => BattleVisualEffect.heal,
      _ => BattleVisualEffect.cannon,
    };
  }

  static BattleActor _actorForPlayerTurn({
    required BattleQuestion question,
    required bool isCorrect,
  }) {
    if (question.effect == QuestionEffect.damage) {
      return isCorrect ? BattleActor.player : BattleActor.opponent;
    }

    return isCorrect ? BattleActor.player : BattleActor.opponent;
  }

  static BattleVisualEffect _visualEffectForTurn({
    required BattleQuestion question,
    required bool isCorrect,
  }) {
    if (question.effect == QuestionEffect.heal) {
      return BattleVisualEffect.heal;
    }

    return visualEffectForCategory(question.category);
  }

  static int _clampHp(int value) {
    return value.clamp(0, 100);
  }

  static ({BattlePhase phase, BattleOutcome outcome, int ratingDelta})
  _resolvePhase({
    required int playerHp,
    required int opponentHp,
    required int playerPoints,
    required int opponentPoints,
    required bool hasRemainingQuestions,
  }) {
    if (hasRemainingQuestions && playerHp > 0 && opponentHp > 0) {
      return (
        phase: BattlePhase.inBattle,
        outcome: BattleOutcome.inProgress,
        ratingDelta: 0,
      );
    }

    final BattleOutcome outcome;
    if (playerHp == 0 && opponentHp == 0) {
      outcome = BattleOutcome.draw;
    } else if (opponentHp == 0) {
      outcome = BattleOutcome.win;
    } else if (playerHp == 0) {
      outcome = BattleOutcome.lose;
    } else if (playerHp > opponentHp) {
      outcome = BattleOutcome.win;
    } else if (playerHp < opponentHp) {
      outcome = BattleOutcome.lose;
    } else if (playerPoints > opponentPoints) {
      outcome = BattleOutcome.win;
    } else if (playerPoints < opponentPoints) {
      outcome = BattleOutcome.lose;
    } else {
      outcome = BattleOutcome.draw;
    }

    final int ratingDelta = switch (outcome) {
      BattleOutcome.win => 20,
      BattleOutcome.lose => -12,
      BattleOutcome.draw || BattleOutcome.inProgress => 0,
    };

    return (
      phase: BattlePhase.finished,
      outcome: outcome,
      ratingDelta: ratingDelta,
    );
  }

  static String _resultLabel(BattleOutcome outcome) {
    return switch (outcome) {
      BattleOutcome.win => 'Kamu menang.',
      BattleOutcome.lose => 'Kamu kalah.',
      BattleOutcome.draw => 'Hasil seri.',
      BattleOutcome.inProgress => '',
    };
  }

  static String _attackLabel(String category) {
    return switch (category.toLowerCase()) {
      'verbal' => 'Wizard Bolt',
      'logika' => 'Robot Slam',
      'numerik' => 'Cannon Strike',
      _ => 'Serangan',
    };
  }
}
