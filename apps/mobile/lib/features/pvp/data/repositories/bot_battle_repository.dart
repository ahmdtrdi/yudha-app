import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/mock_question_bank.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';

class BotBattleRepository extends BattleRepository {
  const BotBattleRepository();

  @override
  Future<BattleSessionSeed> createSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return BattleSessionSeed(
      opponentName: 'BOT YUDHA',
      questions: MockQuestionBank.sample(),
    );
  }
}
