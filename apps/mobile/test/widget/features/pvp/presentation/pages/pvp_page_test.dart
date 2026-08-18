import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
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
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  }) async {
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

class _LiveOnlineBattleRepository extends OnlineBattleRepository {
  final StreamController<OnlineBattleUpdate> _updates =
      StreamController<OnlineBattleUpdate>.broadcast(sync: true);

  OnlineMatchmakingMode? lastMatchmakingMode;

  @override
  Stream<OnlineBattleUpdate> get updates => _updates.stream;

  void emit(OnlineBattleUpdate update) => _updates.add(update);

  @override
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  }) async {
    lastMatchmakingMode = matchmakingMode;
    return const BattleSessionSeed(
      opponentName: 'Bima Saputra',
      questions: <BattleQuestion>[],
    );
  }

  @override
  Future<void> cancelQueue() async {}

  @override
  void dispose() {
    _updates.close();
  }

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

String? _assetName(ImageProvider<Object> provider) {
  ImageProvider<Object> current = provider;
  while (current is ResizeImage) {
    current = current.imageProvider;
  }
  return current is AssetImage ? current.assetName : null;
}

void main() {
  testWidgets('locks arenas that do not match the profile target', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
        profileSettingsStorageProvider.overrideWithValue(
          _MemoryProfileSettingsStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(profileSettingsProvider.notifier)
        .setTarget(ProfileTarget.cpns);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Tujuan CPNS aktif. Arena lain terkunci agar materi dan '
        'lawan tetap sesuai tujuan belajarmu.',
      ),
      findsOneWidget,
    );
    expect(find.text('TERKUNCI'), findsOneWidget);
    expect(
      find.text(
        'Pindah tujuan Anda di Pengaturan jika ingin bermain di Arena BUMN.',
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('arena-choice-arena-bumn')),
    );
    await tester.pump();

    expect(
      container.read(gameEconomyProvider).equippedArenaId,
      GameEconomyCatalog.defaultArenaId,
    );
    expect(
      find.text(
        'Arena ini terkunci untuk tujuan CPNS. Pindah tujuan Anda di '
        'Pengaturan jika ingin bermain di Arena BUMN.',
      ),
      findsOneWidget,
    );

    container
        .read(profileSettingsProvider.notifier)
        .setTarget(ProfileTarget.bumn);
    await tester.pump();
    await tester.pump();

    expect(container.read(gameEconomyProvider).equippedArenaId, 'arena-bumn');
    expect(
      find.text(
        'Pindah tujuan Anda di Pengaturan jika ingin bermain di Arena CPNS.',
      ),
      findsOneWidget,
    );
  });

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
    expect(tester.getTopLeft(find.text('01  PILIH ARENA')).dy, lessThan(100));

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
    expect(
      tester.getTopLeft(find.text('02  SIAPKAN LOADOUT')).dy,
      lessThan(100),
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-arena-blur')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('loadout-character-preview')),
      ),
      tester.getSize(
        find.byKey(const ValueKey<String>('loadout-tower-preview')),
      ),
    );
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey<String>('loadout-character-label')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('loadout-character-preview')),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey<String>('loadout-tower-label')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('loadout-tower-preview')),
            )
            .dy,
      ),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('loadout-preview-character-basic-squire'),
        ),
      ),
      tester.getSize(
        find.byKey(
          const ValueKey<String>('loadout-preview-character-basic-pip'),
        ),
      ),
    );

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
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('online-player-avatar')),
      ),
      tester.getSize(find.byKey(const ValueKey<String>('bot-opponent-avatar'))),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('online-mode-visual'))),
      tester.getSize(find.byKey(const ValueKey<String>('bot-mode-visual'))),
    );
  });

  testWidgets('renders authoritative multiplayer loadout and TWK card asset', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _LiveOnlineBattleRepository online = _LiveOnlineBattleRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        onlineBattleRepositoryProvider.overrideWithValue(online),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(battleControllerProvider.notifier);
    controller.enterArena();
    controller.setMode(BattleMode.online);
    await controller.startBattle();
    online.emit(
      const GameStateUpdated(
        roomId: 'room-assets',
        phase: 'active',
        playerHp: 100,
        opponentHp: 100,
        playerPoints: 0,
        opponentPoints: 0,
        playerComboLevel: 1,
        currentRound: 1,
        roundSecondsRemaining: 180,
        playerRoundWins: 0,
        opponentRoundWins: 0,
        lastRoundOutcome: null,
        availableQuestions: <BattleQuestion>[
          BattleQuestion(
            id: 'twk-card',
            prompt: 'Dasar negara Indonesia?',
            options: <String>['Pancasila', 'Konstitusi'],
            weight: 1,
            effect: QuestionEffect.damage,
            category: 'twk',
          ),
        ],
        answeredQuestionIds: <String>[],
        playerDisplayName: 'Raka Pratama',
        opponentDisplayName: 'Bima Saputra',
        playerCharacterId: 'character-rare-ignis',
        playerTowerId: 'tower-benteng-bara',
        opponentCharacterId: 'character-basic-pip',
        opponentTowerId: 'tower-garda-biru',
      ),
    );
    expect(controller.state.playerCharacterId, 'character-rare-ignis');
    expect(controller.state.playerTowerId, 'tower-benteng-bara');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Bima'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Image &&
            _assetName(widget.image) == 'assets/game/rare_ignis_idle.webp',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Image &&
            _assetName(widget.image) == 'assets/game/arena_turret_coral.webp',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Image &&
            _assetName(widget.image) == 'assets/game/card_twk.webp',
      ),
      findsOneWidget,
    );
  });

  testWidgets('clicking Lawan Bot starts session with OnlineMatchmakingMode.bot', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _LiveOnlineBattleRepository online = _LiveOnlineBattleRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        onlineBattleRepositoryProvider.overrideWithValue(online),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    // Navigate from arena selection -> loadout -> mode selection
    await tester.tap(find.byKey(const ValueKey<String>('continue-to-loadout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('continue-to-mode')));
    await tester.pumpAndSettle();

    // Tap Lawan Bot
    await tester.tap(find.byKey(const ValueKey<String>('mode-bot')));
    await tester.pump();

    expect(online.lastMatchmakingMode, OnlineMatchmakingMode.bot);
  });

  testWidgets('renders in-battle view and responds to server game_state_update and match_result', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _LiveOnlineBattleRepository online = _LiveOnlineBattleRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        onlineBattleRepositoryProvider.overrideWithValue(online),
      ],
    );
    addTearDown(container.dispose);

    final battleController = container.read(battleControllerProvider.notifier);
    battleController.enterArena();
    battleController.setOnlineMatchmakingMode(OnlineMatchmakingMode.bot);
    await battleController.startBattle();

    online.emit(
      const GameStateUpdated(
        roomId: 'room-bot-1',
        phase: 'active',
        playerHp: 100,
        opponentHp: 100,
        playerPoints: 0,
        opponentPoints: 0,
        playerComboLevel: 1,
        currentRound: 1,
        roundSecondsRemaining: 180,
        playerRoundWins: 0,
        opponentRoundWins: 0,
        lastRoundOutcome: null,
        availableQuestions: <BattleQuestion>[
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
        ],
        answeredQuestionIds: <String>[],
        playerDisplayName: 'Kamu',
        opponentDisplayName: 'BOT YUDHA',
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PvpPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('question-card-q1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('question-card-q2')), findsOneWidget);
    expect(find.text('BOT'), findsWidgets);
    expect(find.text('Kamu'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('combo-meter')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('round-clock')), findsOneWidget);

    // Answer a question to generate answer history for performance insight
    await battleController.prepareQuestion(
      const BattleQuestion(
        id: 'q1',
        prompt: '2 + 2 = ?',
        options: <String>['4', '5'],
        correctOptionIndex: 0,
        weight: 4,
        effect: QuestionEffect.damage,
        category: 'numerik',
      ),
    );
    online.emit(
      const CardPlayedUpdate(
        cardId: 'q1',
        correct: true,
        effect: QuestionEffect.damage,
        effectValue: 4,
        projectileLevel: 1,
        isSelfAction: true,
        category: 'numerik',
      ),
    );

    // Emit match finished
    online.emit(
      const MatchResultUpdate(
        outcome: BattleOutcome.win,
        reason: 'opponent_hp_zero',
        ratingDelta: 20,
        coinsDelta: 50,
        progressionPersisted: true,
        matchmakingMode: OnlineMatchmakingMode.bot,
      ),
    );
    await tester.pump();

    expect(find.text('VICTORY!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('battle-performance-insight')),
      findsOneWidget,
    );
  });
}

class _MemoryEconomyStorage implements GameEconomyStorage {
  @override
  Future<GameEconomyState?> load() async => null;

  @override
  Future<void> save(GameEconomyState state) async {}
}

class _MemoryProfileSettingsStorage implements ProfileSettingsStorage {
  @override
  Future<ProfileSettings?> load() async => null;

  @override
  Future<void> save(ProfileSettings settings) async {}
}
