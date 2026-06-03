import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

sealed class OnlineBattleUpdate {
  const OnlineBattleUpdate();
}

class QueueJoinedUpdate extends OnlineBattleUpdate {
  const QueueJoinedUpdate({required this.position, required this.queueDepth});

  final int position;
  final int queueDepth;
}

class QueueCancelledUpdate extends OnlineBattleUpdate {
  const QueueCancelledUpdate({required this.reason});

  final String reason;
}

class MatchFoundUpdate extends OnlineBattleUpdate {
  const MatchFoundUpdate({required this.roomId, required this.opponentUserId});

  final String roomId;
  final String opponentUserId;
}

class GameStateUpdated extends OnlineBattleUpdate {
  const GameStateUpdated({
    required this.roomId,
    required this.phase,
    required this.playerHp,
    required this.opponentHp,
    required this.playerPoints,
    required this.opponentPoints,
    required this.availableQuestions,
    required this.answeredQuestionIds,
  });

  final String roomId;
  final String phase;
  final int playerHp;
  final int opponentHp;
  final int playerPoints;
  final int opponentPoints;
  final List<BattleQuestion> availableQuestions;
  final List<String> answeredQuestionIds;
}

class CardPlayedUpdate extends OnlineBattleUpdate {
  const CardPlayedUpdate({
    required this.cardId,
    required this.correct,
    required this.effect,
    required this.effectValue,
  });

  final String cardId;
  final bool correct;
  final QuestionEffect? effect;
  final int effectValue;
}

class MatchResultUpdate extends OnlineBattleUpdate {
  const MatchResultUpdate({required this.outcome, required this.reason});

  final BattleOutcome outcome;
  final String reason;
}

class PresenceUpdated extends OnlineBattleUpdate {
  const PresenceUpdated({required this.opponentConnected});

  final bool opponentConnected;
}

class BattleErrorUpdate extends OnlineBattleUpdate {
  const BattleErrorUpdate({required this.message});

  final String message;
}
