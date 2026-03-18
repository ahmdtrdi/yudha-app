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
    this.statusMessage,
    this.errorMessage,
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
      statusMessage: 'Pilih mode lalu mulai battle.',
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
  final String? statusMessage;
  final String? errorMessage;

  bool get isBattleActive => phase == BattlePhase.inBattle;
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
    String? statusMessage,
    String? errorMessage,
    bool clearStatusMessage = false,
    bool clearErrorMessage = false,
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
      statusMessage: clearStatusMessage
          ? null
          : statusMessage ?? this.statusMessage,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
