import 'dart:math';

import 'package:yudha_mobile/features/pvp/domain/entities/battle_answer_record.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';

final Random _recycleRandom = Random();

abstract final class BattleStateMachine {
  static BattleState resolveTurn({
    required BattleState state,
    required BattleQuestion question,
    required int selectedOptionIndex,
  }) {
    final bool isCorrect = selectedOptionIndex == question.correctOptionIndex;
    final int comboEffect = effectFromCombo(state.comboLevel);

    int playerHp = state.playerHp;
    int opponentHp = state.opponentHp;
    int playerPoints = state.playerPoints;
    int opponentPoints = state.opponentPoints;

    late final String statusMessage;

    if (question.effect == QuestionEffect.damage) {
      if (isCorrect) {
        opponentHp -= comboEffect;
        playerPoints += comboEffect;
        statusMessage =
            '${_attackLabel(question.category)} x${state.comboLevel} masuk. '
            'Musuh menerima $comboEffect damage.';
      } else {
        final int reflectedDamage = effectFromCombo(1);
        playerHp -= reflectedDamage;
        opponentPoints += reflectedDamage;
        statusMessage =
            'Jawaban kurang tepat. Kamu menerima $reflectedDamage damage.';
      }
    } else {
      if (isCorrect) {
        playerHp += comboEffect;
        playerPoints += comboEffect;
        statusMessage =
            'TWK Heal x${state.comboLevel} aktif. '
            'Kamu memulihkan HP sebesar $comboEffect.';
      } else {
        final int opponentHeal = max(1, comboEffect ~/ 2);
        opponentHp += opponentHeal;
        opponentPoints += opponentHeal;
        statusMessage =
            'Jawaban kurang tepat. Musuh memulihkan HP $opponentHeal.';
      }
    }

    playerHp = _clampHp(playerHp);
    opponentHp = _clampHp(opponentHp);

    List<BattleQuestion> remainingQuestions = state.availableQuestions
        .where((BattleQuestion item) => item.id != question.id)
        .toList(growable: false);

    List<String> answeredQuestions = <String>[
      ...state.answeredQuestionIds,
      question.id,
    ];

    // Recycle questions when pool is exhausted
    if (remainingQuestions.isEmpty) {
      remainingQuestions = _recycleQuestions(
        state.availableQuestions,
        question,
      );
      answeredQuestions = const <String>[];
    }

    return state.copyWith(
      playerHp: playerHp,
      opponentHp: opponentHp,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      availableQuestions: remainingQuestions,
      answeredQuestionIds: answeredQuestions,
      answerHistory: <BattleAnswerRecord>[
        ...state.answerHistory,
        BattleAnswerRecord(
          questionId: question.id,
          prompt: question.prompt,
          category: question.category,
          isCorrect: isCorrect,
        ),
      ],
      battleEventId: state.battleEventId + 1,
      lastActor: _actorForPlayerTurn(question: question, isCorrect: isCorrect),
      lastVisualEffect: _visualEffectForTurn(
        question: question,
        isCorrect: isCorrect,
      ),
      lastEventCategory: question.category,
      statusMessage: statusMessage,
      clearErrorMessage: true,
    );
  }

  static BattleState resolveOpponentTurn({
    required BattleState state,
    required BattleQuestion question,
  }) {
    final int comboEffect = effectFromCombo(1);

    int playerHp = state.playerHp;
    int opponentHp = state.opponentHp;
    final int playerPoints = state.playerPoints;
    int opponentPoints = state.opponentPoints;

    late final String statusMessage;

    if (question.effect == QuestionEffect.heal) {
      opponentHp += comboEffect;
      opponentPoints += comboEffect;
      statusMessage =
          'BOT YUDHA menjawab TWK. Musuh memulihkan HP $comboEffect.';
    } else {
      playerHp -= comboEffect;
      opponentPoints += comboEffect;
      statusMessage =
          'BOT YUDHA menjawab benar. Kamu menerima $comboEffect damage.';
    }

    playerHp = _clampHp(playerHp);
    opponentHp = _clampHp(opponentHp);

    return state.copyWith(
      playerHp: playerHp,
      opponentHp: opponentHp,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      // The visible question pool belongs to the player. An incoming attack
      // must never consume or reshuffle a card the player has not used.
      availableQuestions: state.availableQuestions,
      answeredQuestionIds: state.answeredQuestionIds,
      battleEventId: state.battleEventId + 1,
      lastActor: BattleActor.opponent,
      lastVisualEffect: question.effect == QuestionEffect.heal
          ? BattleVisualEffect.heal
          : visualEffectForCategory(question.category),
      lastEventCategory: question.category,
      statusMessage: statusMessage,
      clearErrorMessage: true,
    );
  }

  static int effectFromCombo(int comboLevel) {
    return comboLevel.clamp(1, 3) * 5;
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

  static String _attackLabel(String category) {
    return switch (category.toLowerCase()) {
      'verbal' => 'Wizard Bolt',
      'logika' => 'Robot Slam',
      'numerik' => 'Cannon Strike',
      _ => 'Serangan',
    };
  }

  /// Recycles a fresh question pool when the current pool is exhausted.
  ///
  /// Prefer another available source over the card that was just answered. A
  /// one-card pool has no alternative, so reusing that card is the only way to
  /// keep an active local battle playable.
  static List<BattleQuestion> _recycleQuestions(
    List<BattleQuestion> sourceQuestions,
    BattleQuestion justAnswered,
  ) {
    final int epoch = DateTime.now().millisecondsSinceEpoch;
    final List<BattleQuestion> alternatives = sourceQuestions
        .where((BattleQuestion item) => item.id != justAnswered.id)
        .toList(growable: false);
    final List<BattleQuestion> recycleSource = alternatives.isNotEmpty
        ? alternatives
        : <BattleQuestion>[justAnswered];
    final List<BattleQuestion> recycled = recycleSource
        .map(
          (BattleQuestion item) => BattleQuestion(
            id: '${item.category}-r$epoch-${_recycleRandom.nextInt(99999)}',
            prompt: item.prompt,
            options: item.options,
            correctOptionIndex: item.correctOptionIndex,
            weight: item.weight,
            effect: item.effect,
            category: item.category,
          ),
        )
        .toList(growable: false);
    recycled.shuffle(_recycleRandom);
    return recycled;
  }
}
