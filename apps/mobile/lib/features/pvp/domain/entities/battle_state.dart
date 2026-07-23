import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

class BattleState {
  const BattleState({
    required this.mode,
    required this.phase,
    required this.outcome,
    required this.opponentName,
    required this.playerHp,
    required this.opponentHp,
    required this.playerPoints,
    required this.opponentPoints,
    required this.ratingDelta,
    required this.availableQuestions,
    required this.answeredQuestionIds,
    required this.isLoading,
    required this.rewardClaimed,
    required this.battleEventId,
    required this.comboLevel,
    required this.comboSecondsRemaining,
    required this.lastProjectileLevel,
    required this.currentRound,
    required this.playerRoundWins,
    required this.opponentRoundWins,
    required this.roundSecondsRemaining,
    this.statusMessage,
    this.errorMessage,
    this.lastActor,
    this.lastVisualEffect,
    this.lastEventCategory,
    this.lastRoundOutcome,
  });

  factory BattleState.initial() {
    return const BattleState(
      mode: BattleMode.bot,
      phase: BattlePhase.preBattle,
      outcome: BattleOutcome.inProgress,
      opponentName: 'BOT YUDHA',
      playerHp: 100,
      opponentHp: 100,
      playerPoints: 0,
      opponentPoints: 0,
      ratingDelta: 0,
      availableQuestions: <BattleQuestion>[],
      answeredQuestionIds: <String>[],
      isLoading: false,
      rewardClaimed: false,
      battleEventId: 0,
      comboLevel: 1,
      comboSecondsRemaining: 0,
      lastProjectileLevel: 1,
      currentRound: 1,
      playerRoundWins: 0,
      opponentRoundWins: 0,
      roundSecondsRemaining: 180,
    );
  }

  final BattleMode mode;
  final BattlePhase phase;
  final BattleOutcome outcome;
  final String opponentName;
  final int playerHp;
  final int opponentHp;
  final int playerPoints;
  final int opponentPoints;
  final int ratingDelta;
  final List<BattleQuestion> availableQuestions;
  final List<String> answeredQuestionIds;
  final bool isLoading;
  final bool rewardClaimed;
  final int battleEventId;
  final int comboLevel;
  final int comboSecondsRemaining;
  final int lastProjectileLevel;
  final int currentRound;
  final int playerRoundWins;
  final int opponentRoundWins;
  final int roundSecondsRemaining;
  final String? statusMessage;
  final String? errorMessage;
  final BattleActor? lastActor;
  final BattleVisualEffect? lastVisualEffect;
  final String? lastEventCategory;
  final BattleOutcome? lastRoundOutcome;

  bool get isBattleActive => phase == BattlePhase.inBattle;
  bool get isMatchActive =>
      phase == BattlePhase.inBattle || phase == BattlePhase.roundBreak;
  bool get isBattleFinished => phase == BattlePhase.finished;

  BattleState copyWith({
    BattleMode? mode,
    BattlePhase? phase,
    BattleOutcome? outcome,
    String? opponentName,
    int? playerHp,
    int? opponentHp,
    int? playerPoints,
    int? opponentPoints,
    int? ratingDelta,
    List<BattleQuestion>? availableQuestions,
    List<String>? answeredQuestionIds,
    bool? isLoading,
    bool? rewardClaimed,
    int? battleEventId,
    int? comboLevel,
    int? comboSecondsRemaining,
    int? lastProjectileLevel,
    int? currentRound,
    int? playerRoundWins,
    int? opponentRoundWins,
    int? roundSecondsRemaining,
    String? statusMessage,
    String? errorMessage,
    BattleActor? lastActor,
    BattleVisualEffect? lastVisualEffect,
    String? lastEventCategory,
    BattleOutcome? lastRoundOutcome,
    bool clearStatusMessage = false,
    bool clearErrorMessage = false,
    bool clearBattleEvent = false,
    bool clearLastRoundOutcome = false,
  }) {
    return BattleState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      outcome: outcome ?? this.outcome,
      opponentName: opponentName ?? this.opponentName,
      playerHp: playerHp ?? this.playerHp,
      opponentHp: opponentHp ?? this.opponentHp,
      playerPoints: playerPoints ?? this.playerPoints,
      opponentPoints: opponentPoints ?? this.opponentPoints,
      ratingDelta: ratingDelta ?? this.ratingDelta,
      availableQuestions: availableQuestions ?? this.availableQuestions,
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      isLoading: isLoading ?? this.isLoading,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      battleEventId: battleEventId ?? this.battleEventId,
      comboLevel: comboLevel ?? this.comboLevel,
      comboSecondsRemaining:
          comboSecondsRemaining ?? this.comboSecondsRemaining,
      lastProjectileLevel: lastProjectileLevel ?? this.lastProjectileLevel,
      currentRound: currentRound ?? this.currentRound,
      playerRoundWins: playerRoundWins ?? this.playerRoundWins,
      opponentRoundWins: opponentRoundWins ?? this.opponentRoundWins,
      roundSecondsRemaining:
          roundSecondsRemaining ?? this.roundSecondsRemaining,
      statusMessage: clearStatusMessage
          ? null
          : statusMessage ?? this.statusMessage,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      lastActor: clearBattleEvent ? null : lastActor ?? this.lastActor,
      lastVisualEffect: clearBattleEvent
          ? null
          : lastVisualEffect ?? this.lastVisualEffect,
      lastEventCategory: clearBattleEvent
          ? null
          : lastEventCategory ?? this.lastEventCategory,
      lastRoundOutcome: clearLastRoundOutcome
          ? null
          : lastRoundOutcome ?? this.lastRoundOutcome,
    );
  }
}
