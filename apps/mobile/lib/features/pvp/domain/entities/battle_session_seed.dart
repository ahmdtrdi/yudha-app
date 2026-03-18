import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

class BattleSessionSeed {
  const BattleSessionSeed({
    required this.opponentName,
    required this.questions,
  });

  final String opponentName;
  final List<BattleQuestion> questions;
}
