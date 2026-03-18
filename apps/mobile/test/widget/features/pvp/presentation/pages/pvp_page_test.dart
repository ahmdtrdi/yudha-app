import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/battle_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page.dart';

class _FakeBattleRepository extends BattleRepository {
  const _FakeBattleRepository(this.seed);

  final BattleSessionSeed seed;

  @override
  Future<BattleSessionSeed> createSession() async {
    return seed;
  }
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          botBattleRepositoryProvider.overrideWithValue(
            const _FakeBattleRepository(seed),
          ),
          onlineBattleRepositoryProvider.overrideWithValue(
            const _FakeBattleRepository(seed),
          ),
        ],
        child: const MaterialApp(home: PvpPage()),
      ),
    );

    expect(find.text('Mulai Battle'), findsOneWidget);

    await tester.tap(find.text('Mulai Battle'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('question-card-q1')),
      findsOneWidget,
    );
    expect(find.text('BOT TEST'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('question-card-q1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(find.text('VICTORY!'), findsOneWidget);
  });
}
