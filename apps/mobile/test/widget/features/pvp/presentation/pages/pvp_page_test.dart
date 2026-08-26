import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
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
        gameEconomyRepositoryProvider.overrideWithValue(
          _PvpEconomyRepository(),
        ),
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
    expect(find.text('Terkunci'), findsOneWidget);
    expect(find.text('Arena CPNS'), findsOneWidget);
    expect(find.text('BUMN'), findsOneWidget);

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
    expect(find.text('Arena BUMN'), findsOneWidget);
    expect(find.text('CPNS'), findsOneWidget);
    expect(find.text('Terkunci'), findsOneWidget);
  });

  testWidgets('follows arena, loadout, and mode setup flow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
        gameEconomyRepositoryProvider.overrideWithValue(
          _PvpEconomyRepository(),
        ),
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

    expect(find.text('Mau bertanding di mana?'), findsOneWidget);
    expect(find.text('Arena CPNS'), findsOneWidget);
    expect(find.text('BUMN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('arena-selected-showcase')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey<String>('setup-progress-step-3')),
          )
          .color,
      const Color(0xFFD8D3C8),
    );
    expect(tester.getTopLeft(find.text('01  PILIH ARENA')).dy, lessThan(100));

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
      find.byKey(const ValueKey<String>('loadout-fixed-layout')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('loadout-fixed-layout')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('02  SIAPKAN LOADOUT')).dy,
      lessThan(100),
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-arena-blur')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey<String>('setup-progress-step-2')),
          )
          .color,
      const Color(0xFF173A67),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey<String>('setup-progress-step-3')),
          )
          .color,
      const Color(0xFFD8D3C8),
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
      find.byKey(const ValueKey<String>('loadout-karakter-previous')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-karakter-next')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-tower-next')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-karakter-carousel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-tower-carousel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-character-rare-ignis')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loadout-lock-character-rare-ignis')),
      findsOneWidget,
    );

    final Finder characterCarousel = find.byKey(
      const ValueKey<String>('loadout-karakter-carousel'),
    );
    final double ignisBeforeDrag = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('loadout-character-rare-ignis')),
        )
        .dx;
    await tester.drag(characterCarousel, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('loadout-character-rare-ignis')),
          )
          .dx,
      lessThan(ignisBeforeDrag),
    );

    await tester.drag(characterCarousel, const Offset(260, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('loadout-character-basic-squire')),
    );
    await tester.pumpAndSettle();
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
    final double loadoutHeaderTop = tester
        .getTopLeft(find.text('Siapkan loadout'))
        .dy;

    await tester.tap(find.byKey(const ValueKey<String>('continue-to-mode')));
    await tester.pumpAndSettle();

    expect(find.text('Pilih mode'), findsOneWidget);
    expect(find.text('03  PILIH MODE'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Pilih mode')).dy,
      closeTo(loadoutHeaderTop, 1),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey<String>('setup-progress-step-3')),
          )
          .color,
      const Color(0xFF173A67),
    );

    expect(find.text('Siap bertanding, Kamu?'), findsOneWidget);
    expect(find.text('Lawan Bot'), findsOneWidget);
    expect(find.text('Lawan Player'), findsOneWidget);
    expect(find.text('Ranked Match'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mode-selected-showcase')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('mode-bot')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mode-choice-bot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-choice-online')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-choice-ranked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-illustration-bot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-illustration-online')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-illustration-ranked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-selected-arena')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-selected-character-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mode-selected-tower')),
      findsOneWidget,
    );
    expect(
      ((tester
                          .widget<AnimatedContainer>(
                            find.byKey(
                              const ValueKey<String>('mode-selected-showcase'),
                            ),
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .color,
      const Color(0x822878F0),
    );

    final String? arenaAsset = _assetName(
      tester
          .widget<Image>(
            find.byKey(const ValueKey<String>('mode-selected-arena')),
          )
          .image,
    );
    final String? characterAsset = _assetName(
      tester
          .widget<Image>(
            find.byKey(const ValueKey<String>('mode-selected-character-image')),
          )
          .image,
    );
    final String? towerAsset = _assetName(
      tester
          .widget<Image>(
            find.byKey(const ValueKey<String>('mode-selected-tower')),
          )
          .image,
    );

    await tester.tap(find.byKey(const ValueKey<String>('mode-choice-online')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('mode-online')), findsOneWidget);
    expect(
      ((tester
                          .widget<AnimatedContainer>(
                            find.byKey(
                              const ValueKey<String>('mode-selected-showcase'),
                            ),
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .color,
      const Color(0x827559D4),
    );

    final Finder rankedChoice = find.byKey(
      const ValueKey<String>('mode-choice-ranked'),
    );
    await tester.ensureVisible(rankedChoice);
    await tester.pumpAndSettle();
    await tester.tap(rankedChoice);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('mode-ranked')), findsOneWidget);
    expect(
      ((tester
                          .widget<AnimatedContainer>(
                            find.byKey(
                              const ValueKey<String>('mode-selected-showcase'),
                            ),
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .color,
      const Color(0x82E0922F),
    );
    expect(
      _assetName(
        tester
            .widget<Image>(
              find.byKey(const ValueKey<String>('mode-selected-arena')),
            )
            .image,
      ),
      arenaAsset,
    );
    expect(
      _assetName(
        tester
            .widget<Image>(
              find.byKey(
                const ValueKey<String>('mode-selected-character-image'),
              ),
            )
            .image,
      ),
      characterAsset,
    );
    expect(
      _assetName(
        tester
            .widget<Image>(
              find.byKey(const ValueKey<String>('mode-selected-tower')),
            )
            .image,
      ),
      towerAsset,
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

  testWidgets(
    'clicking Lawan Bot starts session with OnlineMatchmakingMode.bot',
    (WidgetTester tester) async {
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
      await tester.tap(
        find.byKey(const ValueKey<String>('continue-to-loadout')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('continue-to-mode')));
      await tester.pumpAndSettle();

      // Tap Lawan Bot
      await tester.tap(find.byKey(const ValueKey<String>('mode-bot')));
      await tester.pump();

      expect(online.lastMatchmakingMode, OnlineMatchmakingMode.bot);
    },
  );

  testWidgets(
    'renders in-battle view and responds to server game_state_update and match_result',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _LiveOnlineBattleRepository online = _LiveOnlineBattleRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          onlineBattleRepositoryProvider.overrideWithValue(online),
        ],
      );
      addTearDown(container.dispose);

      final battleController = container.read(
        battleControllerProvider.notifier,
      );
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
              prompt:
                  'Peran BUMN sebagai benteng kedaulatan ekonomi negara '
                  'berdasarkan pilar UUD 1945 diwujudkan melalui tindakan apa?',
              options: <String>['Lekas', 'Lambat'],
              correctOptionIndex: 0,
              weight: 4,
              effect: QuestionEffect.damage,
              category: 'wawasan_kebangsaan',
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

      expect(
        find.byKey(const ValueKey<String>('question-card-q1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('question-card-q2')),
        findsOneWidget,
      );
      expect(find.text('BOT'), findsWidgets);
      expect(find.text('Kamu'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('combo-meter')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('round-clock')), findsOneWidget);
      final DecoratedBox battleStage = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('in-battle-stage')),
      );
      expect(
        (battleStage.decoration as BoxDecoration).gradient,
        isA<LinearGradient>(),
      );
      final Container opponentHud = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-hud-opponent')),
      );
      expect((opponentHud.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      final Container arenaBoard = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-arena-board')),
      );
      expect(arenaBoard.padding, const EdgeInsets.all(5));
      final Container battleHand = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-hand')),
      );
      final BoxDecoration battleHandDecoration =
          battleHand.decoration! as BoxDecoration;
      expect(battleHandDecoration.borderRadius, isNull);
      expect(battleHandDecoration.boxShadow, isNull);
      final Container playerHud = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-hud-player')),
      );
      expect((playerHud.decoration! as BoxDecoration).boxShadow, isNull);
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(390, 700));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('battle-arena-board')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey<String>('question-card-q2')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('question-battle-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('question-sheet-scroll-view')),
        findsOneWidget,
      );
      final Container questionHeader = tester.widget<Container>(
        find.byKey(const ValueKey<String>('question-sheet-header')),
      );
      expect((questionHeader.decoration! as BoxDecoration).boxShadow, isNull);
      final Container promptCard = tester.widget<Container>(
        find.byKey(const ValueKey<String>('question-prompt-card')),
      );
      expect((promptCard.decoration! as BoxDecoration).boxShadow, isNull);
      expect(
        find.byKey(const ValueKey<String>('question-timer-ring')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('question-online-status')),
        findsNothing,
      );
      final Container answerGroup = tester.widget<Container>(
        find.byKey(const ValueKey<String>('question-answer-group')),
      );
      expect((answerGroup.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      final AnimatedContainer answerOption = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey<String>('question-answer-0')),
      );
      expect((answerOption.decoration! as BoxDecoration).boxShadow, isNull);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('question-answer-0')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const ValueKey<String>('question-battle-sheet')),
        findsNothing,
      );
      expect(find.textContaining('Jawaban dikirim'), findsNothing);
      expect(tester.takeException(), isNull);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey<String>('battle-answer-result-true')),
        findsOneWidget,
      );
      expect(find.text('BENAR'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('battle-hand-helper')),
        findsNothing,
      );

      online.emit(
        const CardPlayedUpdate(
          cardId: 'q2',
          correct: false,
          effect: QuestionEffect.damage,
          effectValue: 4,
          projectileLevel: 1,
          isSelfAction: true,
          category: 'wawasan_kebangsaan',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey<String>('battle-answer-result-false')),
        findsOneWidget,
      );
      expect(find.text('SALAH'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey<String>('battle-answer-result')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('battle-hand-helper')),
        findsOneWidget,
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
        find.byKey(const ValueKey<String>('battle-result-hero')),
        findsOneWidget,
      );
      final Container resultHero = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-result-hero-surface')),
      );
      expect((resultHero.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      expect(
        find.byKey(const ValueKey<String>('battle-result-score-card')),
        findsOneWidget,
      );
      final Container scoreSection = tester.widget<Container>(
        find.byKey(const ValueKey<String>('battle-result-score-card')),
      );
      expect((scoreSection.decoration! as BoxDecoration).boxShadow, isNull);
      expect(
        find.byKey(const ValueKey<String>('battle-result-reward-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('battle-performance-insight')),
        findsOneWidget,
      );
      expect(find.textContaining('Wawasan Kebangsaan'), findsWidgets);
      expect(find.text('Lihat lengkap'), findsOneWidget);
      await tester.ensureVisible(find.text('Lihat lengkap'));
      await tester.pump();
      await tester.tap(find.text('Lihat lengkap'));
      await tester.pump();
      expect(find.text('Ringkas'), findsOneWidget);
      expect(find.text('KLAIM HADIAH'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('battle-result-primary-action')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('battle-result-primary-action')),
      );
      await tester.pump();
      expect(find.text('Diklaim'), findsOneWidget);
      expect(find.text('Main lagi'), findsOneWidget);
      expect(find.text('Pilih mode'), findsOneWidget);

      await tester.ensureVisible(find.text('Main lagi'));
      await tester.pump();
      expect(
        tester.getCenter(find.text('Main lagi')).dy,
        tester.getCenter(find.text('Pilih mode')).dy,
      );
    },
  );
}

class _MemoryEconomyStorage implements GameEconomyStorage {
  @override
  Future<GameEconomyState?> load() async => null;

  @override
  Future<void> save(GameEconomyState state) async {}

  @override
  Future<void> clear() async {}
}

class _PvpEconomyRepository extends GameEconomyRepository {
  String characterId = 'character-basic-pip';
  String towerId = 'tower-benteng-bara';
  String arenaId = GameEconomyCatalog.defaultArenaId;

  AuthoritativeEconomySnapshot get snapshot => AuthoritativeEconomySnapshot(
    coins: 3000,
    ownedItemIds: const <String>{
      GameEconomyCatalog.defaultCharacterId,
      GameEconomyCatalog.defaultTowerId,
      'character-basic-pip',
      'tower-benteng-bara',
    },
    characterId: characterId,
    towerId: towerId,
    arenaId: arenaId,
    items: GameEconomyCatalog.cosmetics,
  );

  @override
  Future<AuthoritativeEconomySnapshot> fetch() async => snapshot;

  @override
  Future<AuthoritativeEconomySnapshot> grantBetaCredit({
    int coins = 100,
  }) async => snapshot;

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(
    CosmeticItem item,
  ) async => snapshot;

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async {
    this.characterId = characterId ?? this.characterId;
    this.towerId = towerId ?? this.towerId;
    this.arenaId = arenaId ?? this.arenaId;
    return snapshot;
  }
}

class _MemoryProfileSettingsStorage implements ProfileSettingsStorage {
  @override
  Future<ProfileSettings?> load() async => null;

  @override
  Future<void> save(ProfileSettings settings) async {}
}
