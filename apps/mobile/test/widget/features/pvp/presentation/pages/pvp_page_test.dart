import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page.dart';

class _FakeBattleRepository extends OnlineBattleRepository {
  const _FakeBattleRepository(this.seed);

  final BattleSessionSeed seed;

  @override
  Stream<OnlineBattleUpdate> get updates =>
      const Stream<OnlineBattleUpdate>.empty();

  @override
  Future<BattleSessionSeed> createSession() async {
    return seed;
  }

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
  testWidgets('transitions from pre-battle to result', (
    WidgetTester tester,
  ) async {
    const BattleSessionSeed seed = BattleSessionSeed(
      opponentName: 'BOT TEST',
      questions: <BattleQuestion>[
        BattleQuestion(
          id: 'q1',
          prompt: '2 + 2 = ?',
          options: <String>['4', '5'],
          correctOptionIndex: 0,
          weight: 2,
          effect: QuestionEffect.damage,
        ),
      ],
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        botBattleRepositoryProvider.overrideWithValue(
          const _FakeBattleRepository(seed),
        ),
        onlineBattleRepositoryProvider.overrideWithValue(
          const _FakeBattleRepository(seed),
        ),
      ],
    );
    addTearDown(container.dispose);

    final battleController = container.read(battleControllerProvider.notifier);
    battleController.enterArena();
    battleController.setMode(BattleMode.bot);
    await battleController.startBattle();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('question-card-q1')),
      findsOneWidget,
    );
    expect(find.text('BOT TEST'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);

    await battleController.answerQuestion(
      questionId: 'q1',
      selectedOptionIndex: 0,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('VICTORY!'), findsOneWidget);
  });
}
