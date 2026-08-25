import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

sealed class OnlineBattleUpdate {
  const OnlineBattleUpdate();
}

class QueueJoinedUpdate extends OnlineBattleUpdate {
  const QueueJoinedUpdate({
    required this.position,
    required this.queueDepth,
    this.matchmakingMode = OnlineMatchmakingMode.casual,
    this.target = BattleTarget.cpns,
  });

  final int position;
  final int queueDepth;
  final OnlineMatchmakingMode matchmakingMode;
  final BattleTarget target;
}

class QueueCancelledUpdate extends OnlineBattleUpdate {
  const QueueCancelledUpdate({required this.reason});

  final String reason;
}

class MatchFoundUpdate extends OnlineBattleUpdate {
  const MatchFoundUpdate({
    required this.roomId,
    required this.opponentUserId,
    required this.opponentDisplayName,
    this.opponentCharacterId,
    this.opponentTowerId,
    this.matchmakingMode = OnlineMatchmakingMode.casual,
    this.target = BattleTarget.cpns,
  });

  final String roomId;
  final String opponentUserId;
  final String opponentDisplayName;
  final String? opponentCharacterId;
  final String? opponentTowerId;
  final OnlineMatchmakingMode matchmakingMode;
  final BattleTarget target;
}

class GameStateUpdated extends OnlineBattleUpdate {
  const GameStateUpdated({
    required this.roomId,
    required this.phase,
    required this.playerHp,
    required this.opponentHp,
    required this.playerPoints,
    required this.opponentPoints,
    required this.playerComboLevel,
    required this.currentRound,
    required this.roundSecondsRemaining,
    required this.playerRoundWins,
    required this.opponentRoundWins,
    required this.lastRoundOutcome,
    required this.availableQuestions,
    required this.answeredQuestionIds,
    required this.playerDisplayName,
    required this.opponentDisplayName,
    this.playerCharacterId,
    this.playerTowerId,
    this.opponentCharacterId,
    this.opponentTowerId,
    this.matchmakingMode = OnlineMatchmakingMode.casual,
    this.target = BattleTarget.cpns,
    this.opponentConnected = true,
  });

  final String roomId;
  final String phase;
  final int playerHp;
  final int opponentHp;
  final int playerPoints;
  final int opponentPoints;
  final int playerComboLevel;
  final int currentRound;
  final int roundSecondsRemaining;
  final int playerRoundWins;
  final int opponentRoundWins;
  final BattleOutcome? lastRoundOutcome;
  final List<BattleQuestion> availableQuestions;
  final List<String> answeredQuestionIds;
  final String playerDisplayName;
  final String opponentDisplayName;
  final String? playerCharacterId;
  final String? playerTowerId;
  final String? opponentCharacterId;
  final String? opponentTowerId;
  final OnlineMatchmakingMode matchmakingMode;
  final BattleTarget target;
  final bool opponentConnected;
}

class CardPlayedUpdate extends OnlineBattleUpdate {
  const CardPlayedUpdate({
    required this.cardId,
    required this.correct,
    required this.effect,
    required this.effectValue,
    required this.projectileLevel,
    required this.isSelfAction,
    this.category,
  });

  final String cardId;
  final bool correct;
  final QuestionEffect? effect;
  final int effectValue;
  final int projectileLevel;
  final bool isSelfAction;
  final String? category;
}

class MatchResultUpdate extends OnlineBattleUpdate {
  const MatchResultUpdate({
    required this.outcome,
    required this.reason,
    required this.ratingDelta,
    required this.coinsDelta,
    required this.progressionPersisted,
    this.matchmakingMode = OnlineMatchmakingMode.casual,
    this.target = BattleTarget.cpns,
  });

  final BattleOutcome outcome;
  final String reason;
  final int ratingDelta;
  final int coinsDelta;
  final bool progressionPersisted;
  final OnlineMatchmakingMode matchmakingMode;
  final BattleTarget target;
}

class PresenceUpdated extends OnlineBattleUpdate {
  const PresenceUpdated({
    required this.opponentConnected,
    this.opponentReconnectDeadline,
  });

  final bool opponentConnected;
  final DateTime? opponentReconnectDeadline;
}

class PrivateRoomCreatedUpdate extends OnlineBattleUpdate {
  const PrivateRoomCreatedUpdate({
    required this.code,
    required this.target,
    required this.expiresAt,
  });

  final String code;
  final BattleTarget target;
  final DateTime expiresAt;
}

class PrivateRoomCancelledUpdate extends OnlineBattleUpdate {
  const PrivateRoomCancelledUpdate({required this.code, required this.reason});

  final String code;
  final String reason;
}

class BattleErrorUpdate extends OnlineBattleUpdate {
  const BattleErrorUpdate({required this.message});

  final String message;
}
