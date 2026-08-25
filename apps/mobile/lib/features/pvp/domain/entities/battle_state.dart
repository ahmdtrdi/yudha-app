import 'package:yudha_mobile/features/pvp/domain/entities/battle_answer_record.dart';
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
    required this.coinsDelta,
    required this.onlineMatchmakingMode,
    required this.availableQuestions,
    required this.answeredQuestionIds,
    required this.answerHistory,
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
    required this.progressionPersisted,
    required this.opponentConnected,
    this.battleTarget,
    this.playerCharacterId,
    this.playerTowerId,
    this.opponentCharacterId,
    this.opponentTowerId,
    this.opponentReconnectDeadline,
    this.privateRoomCode,
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
      coinsDelta: 0,
      onlineMatchmakingMode: OnlineMatchmakingMode.casual,
      availableQuestions: <BattleQuestion>[],
      answeredQuestionIds: <String>[],
      answerHistory: <BattleAnswerRecord>[],
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
      progressionPersisted: false,
      opponentConnected: true,
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
  final int coinsDelta;
  final OnlineMatchmakingMode onlineMatchmakingMode;
  final List<BattleQuestion> availableQuestions;
  final List<String> answeredQuestionIds;
  final List<BattleAnswerRecord> answerHistory;
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
  final bool progressionPersisted;
  final bool opponentConnected;
  final BattleTarget? battleTarget;
  final String? playerCharacterId;
  final String? playerTowerId;
  final String? opponentCharacterId;
  final String? opponentTowerId;
  final DateTime? opponentReconnectDeadline;
  final String? privateRoomCode;
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
    int? coinsDelta,
    OnlineMatchmakingMode? onlineMatchmakingMode,
    List<BattleQuestion>? availableQuestions,
    List<String>? answeredQuestionIds,
    List<BattleAnswerRecord>? answerHistory,
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
    bool? progressionPersisted,
    bool? opponentConnected,
    BattleTarget? battleTarget,
    String? playerCharacterId,
    String? playerTowerId,
    String? opponentCharacterId,
    String? opponentTowerId,
    DateTime? opponentReconnectDeadline,
    String? privateRoomCode,
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
    bool clearBattleTarget = false,
    bool clearPlayerLoadout = false,
    bool clearOpponentLoadout = false,
    bool clearReconnectDeadline = false,
    bool clearPrivateRoomCode = false,
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
      coinsDelta: coinsDelta ?? this.coinsDelta,
      onlineMatchmakingMode:
          onlineMatchmakingMode ?? this.onlineMatchmakingMode,
      availableQuestions: availableQuestions ?? this.availableQuestions,
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      answerHistory: answerHistory ?? this.answerHistory,
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
      progressionPersisted: progressionPersisted ?? this.progressionPersisted,
      opponentConnected: opponentConnected ?? this.opponentConnected,
      battleTarget: clearBattleTarget
          ? null
          : battleTarget ?? this.battleTarget,
      playerCharacterId: clearPlayerLoadout
          ? null
          : playerCharacterId ?? this.playerCharacterId,
      playerTowerId: clearPlayerLoadout
          ? null
          : playerTowerId ?? this.playerTowerId,
      opponentCharacterId: clearOpponentLoadout
          ? null
          : opponentCharacterId ?? this.opponentCharacterId,
      opponentTowerId: clearOpponentLoadout
          ? null
          : opponentTowerId ?? this.opponentTowerId,
      opponentReconnectDeadline: clearReconnectDeadline
          ? null
          : opponentReconnectDeadline ?? this.opponentReconnectDeadline,
      privateRoomCode: clearPrivateRoomCode
          ? null
          : privateRoomCode ?? this.privateRoomCode,
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
