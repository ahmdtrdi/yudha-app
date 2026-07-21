import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';

class _FakeBotRepository extends BattleRepository {
  const _FakeBotRepository(this.seed);

  final BattleSessionSeed seed;

  @override
  Future<BattleSessionSeed> createSession() async => seed;
}

class _FakeOnlineRepository extends OnlineBattleRepository {
  @override
  Stream<OnlineBattleUpdate> get updates =>
      const Stream<OnlineBattleUpdate>.empty();

  @override
  Future<BattleSessionSeed> createSession() async => const BattleSessionSeed(
    opponentName: 'ONLINE TEST',
    questions: <BattleQuestion>[],
  );

  @override
  Future<void> cancelQueue() async {}

  @override
  void dispose() {}

  @override
  Future<void> openCard({required String cardId}) async {}

  @override
  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  }) async {}

  @override
  Future<void> surrender() async {}
}

void main() {
  const BattleQuestion selectedQuestion = BattleQuestion(
    id: 'q-selected',
    prompt: 'Pertanyaan yang sedang dijawab',
    options: <String>['A', 'B'],
    correctOptionIndex: 0,
    weight: 1,
    effect: QuestionEffect.damage,
    category: 'verbal',
  );
  const BattleQuestion botQuestion = BattleQuestion(
    id: 'q-bot',
    prompt: 'Pertanyaan alternatif untuk bot',
    options: <String>['A', 'B'],
    correctOptionIndex: 0,
    weight: 1,
    effect: QuestionEffect.damage,
    category: 'numerik',
  );

  BattleController createController(List<BattleQuestion> questions) {
    return BattleController(
      botRepository: _FakeBotRepository(
        BattleSessionSeed(opponentName: 'BOT TEST', questions: questions),
      ),
      onlineRepository: _FakeOnlineRepository(),
    );
  }

  group('BattleController question reservation', () {
    test(
      'bot consumes an alternative while selected question is open',
      () async {
        final BattleController controller = createController(
          const <BattleQuestion>[selectedQuestion, botQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();

        expect(await controller.prepareQuestion(selectedQuestion), isTrue);
        controller.answerBotQuestion();

        expect(
          controller.state.availableQuestions.map((question) => question.id),
          contains(selectedQuestion.id),
        );
        expect(
          controller.state.availableQuestions.map((question) => question.id),
          isNot(contains(botQuestion.id)),
        );
        expect(controller.state.playerHp, lessThan(100));
      },
    );

    test('bot waits when the prepared question is the only card', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();

      expect(await controller.prepareQuestion(selectedQuestion), isTrue);
      controller.answerBotQuestion();

      expect(controller.state.playerHp, 100);
      expect(controller.state.battleEventId, 0);
      expect(
        controller.state.availableQuestions.single.id,
        selectedQuestion.id,
      );
    });

    test(
      'releasing a prepared question makes it available to the bot',
      () async {
        final BattleController controller = createController(
          const <BattleQuestion>[selectedQuestion],
        );
        addTearDown(controller.dispose);
        controller.setMode(BattleMode.bot);
        await controller.startBattle();
        await controller.prepareQuestion(selectedQuestion);

        controller.releasePreparedQuestion(selectedQuestion.id);
        controller.answerBotQuestion();

        expect(controller.state.playerHp, lessThan(100));
        expect(controller.state.battleEventId, 1);
      },
    );

    test('reset clears the prepared-question reservation', () async {
      final BattleController controller = createController(
        const <BattleQuestion>[selectedQuestion],
      );
      addTearDown(controller.dispose);
      controller.setMode(BattleMode.bot);
      await controller.startBattle();
      await controller.prepareQuestion(selectedQuestion);

      controller.resetBattle();
      await controller.startBattle();
      controller.answerBotQuestion();

      expect(controller.state.playerHp, lessThan(100));
      expect(controller.state.battleEventId, 1);
    });
  });
}
