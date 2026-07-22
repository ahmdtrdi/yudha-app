import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
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
  testWidgets('follows arena, loadout, and mode setup flow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
      ],
    );
    addTearDown(container.dispose);

    final economy = container.read(gameEconomyProvider.notifier);
    economy.topUp(GameEconomyCatalog.topUpPackages[2]);
    economy.purchase(GameEconomyCatalog.characters[1]);
    economy.purchase(GameEconomyCatalog.towers[1]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Mau bertanding di mana?'), findsOneWidget);
    expect(find.text('Arena CPNS'), findsOneWidget);
    expect(find.text('Arena BUMN'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('arena-choice-arena-bumn')),
    );
    await tester.pump();

    expect(container.read(gameEconomyProvider).equippedArenaId, 'arena-bumn');

    await tester.tap(find.byKey(const ValueKey<String>('continue-to-loadout')));
    await tester.pumpAndSettle();

    expect(find.text('Pilih jagoanmu, Kamu'), findsOneWidget);
    expect(find.text('Karakter'), findsOneWidget);
    expect(find.text('Tower'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('loadout-character-basic-squire')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('loadout-tower-garda-biru')),
    );
    await tester.pump();

    expect(
      container.read(gameEconomyProvider).equippedCharacterId,
      GameEconomyCatalog.defaultCharacterId,
    );
    expect(
      container.read(gameEconomyProvider).equippedTowerId,
      GameEconomyCatalog.defaultTowerId,
    );

    await tester.tap(find.byKey(const ValueKey<String>('continue-to-mode')));
    await tester.pumpAndSettle();

    expect(find.text('Siap bertanding, Kamu?'), findsOneWidget);
    expect(find.text('Lawan Bot'), findsOneWidget);
    expect(find.text('Lawan Player'), findsOneWidget);
  });

  testWidgets('transitions from pre-battle to result', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const BattleSessionSeed seed = BattleSessionSeed(
      opponentName: 'BOT TEST',
      questions: <BattleQuestion>[
        BattleQuestion(
          id: 'q1',
          prompt: '2 + 2 = ?',
          options: <String>['4', '5'],
          correctOptionIndex: 0,
          weight: 4,
          effect: QuestionEffect.damage,
          category: 'numerik',
        ),
        BattleQuestion(
          id: 'q2',
          prompt: 'Sinonim cepat?',
          options: <String>['Lekas', 'Lambat'],
          correctOptionIndex: 0,
          weight: 4,
          effect: QuestionEffect.damage,
          category: 'verbal',
        ),
        BattleQuestion(
          id: 'q3',
          prompt: 'Pola berikutnya?',
          options: <String>['8', '9'],
          correctOptionIndex: 0,
          weight: 4,
          effect: QuestionEffect.damage,
          category: 'logika',
        ),
        BattleQuestion(
          id: 'q4',
          prompt: 'Pilih jawaban benar.',
          options: <String>['Benar', 'Salah'],
          correctOptionIndex: 0,
          weight: 4,
          effect: QuestionEffect.damage,
          category: 'numerik',
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
    expect(
      find.byKey(const ValueKey<String>('question-card-q2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('question-card-q3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('question-card-q4')),
      findsOneWidget,
    );
    expect(find.text('BOT TEST'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('combo-meter')), findsOneWidget);

    for (final String questionId in <String>['q1', 'q2', 'q3', 'q4']) {
      await battleController.answerQuestion(
        questionId: questionId,
        selectedOptionIndex: 0,
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('VICTORY!'), findsOneWidget);
  });

  testWidgets('bot keeps attacking while a question sheet is open', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const BattleSessionSeed seed = BattleSessionSeed(
      opponentName: 'BOT REALTIME',
      questions: <BattleQuestion>[
        BattleQuestion(
          id: 'live-q1',
          prompt: 'Pertanyaan yang sedang dijawab',
          options: <String>['A', 'B', 'C', 'D'],
          correctOptionIndex: 0,
          weight: 2,
          effect: QuestionEffect.damage,
          category: 'numerik',
        ),
        BattleQuestion(
          id: 'live-q2',
          prompt: 'Serangan bot satu',
          options: <String>['A', 'B'],
          correctOptionIndex: 0,
          weight: 2,
          effect: QuestionEffect.damage,
          category: 'verbal',
        ),
        BattleQuestion(
          id: 'live-q3',
          prompt: 'Serangan bot dua',
          options: <String>['A', 'B'],
          correctOptionIndex: 0,
          weight: 2,
          effect: QuestionEffect.damage,
          category: 'logika',
        ),
        BattleQuestion(
          id: 'live-q4',
          prompt: 'Serangan bot tiga',
          options: <String>['A', 'B'],
          correctOptionIndex: 0,
          weight: 2,
          effect: QuestionEffect.damage,
          category: 'numerik',
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
    await tester.pump(const Duration(milliseconds: 2900));
    await tester.tap(
      find.byKey(const ValueKey<String>('question-card-live-q1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Pertanyaan yang sedang dijawab'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('assets/game/basic_squire_ready.png')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 6300));

    expect(container.read(battleControllerProvider).playerHp, lessThan(100));
    expect(find.text('Pertanyaan yang sedang dijawab'), findsOneWidget);
  });
}

class _MemoryEconomyStorage implements GameEconomyStorage {
  @override
  Future<GameEconomyState?> load() async => null;

  @override
  Future<void> save(GameEconomyState state) async {}
}
