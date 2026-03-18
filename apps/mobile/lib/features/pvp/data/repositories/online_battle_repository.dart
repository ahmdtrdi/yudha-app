import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/mock_question_bank.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';

class OnlineBattleRepository extends BattleRepository {
  const OnlineBattleRepository();

  @override
  Future<BattleSessionSeed> createSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return BattleSessionSeed(
      opponentName: 'Player Match',
      questions: MockQuestionBank.sample(),
    );
  }
}
