import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/app/router/app_tab_shell.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/lobby/domain/beta_welcome_reward.dart';
import 'package:yudha_mobile/features/lobby/presentation/beta_welcome_dialog.dart';
import 'package:yudha_mobile/features/lobby/presentation/pages/lobby_page.dart';

void main() {
  testWidgets('QA-023 shows a skeleton until initial hydration completes', (
    tester,
  ) async {
    final repository = _ControlledSummaryRepository();
    final progress = PlayerProgressController(
      repository: repository,
      shouldHydrate: true,
    );
    final economy = _LobbyEconomyController();
    await _pumpLobby(tester, progress, economy);
    expect(find.byKey(const ValueKey('lobby-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-profile-header')), findsNothing);
    expect(find.text('Daily Question'), findsNothing);
    expect(find.text('Daily PvP'), findsNothing);
    expect(find.byKey(const ValueKey('lobby-quest-roadmap')), findsNothing);
    repository.requests.single.complete(
      await const _LobbySummaryRepository().fetchCurrentProgress(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lobby-loading')), findsNothing);
    expect(find.text('Selesaikan Practice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-023 shows an error and retries progress and economy', (
    tester,
  ) async {
    final repository = _ControlledSummaryRepository();
    final progress = PlayerProgressController(
      repository: repository,
      shouldHydrate: true,
    );
    final economy = _LobbyEconomyController();
    await _pumpLobby(tester, progress, economy);
    repository.requests.single.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lobby-error')), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-quest-roadmap')), findsNothing);
    expect(find.byKey(const ValueKey('lobby-missions-empty')), findsNothing);
    economy.pending = Completer<void>();
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(economy.refreshCalls, 1);
    expect(find.byKey(const ValueKey('lobby-loading')), findsOneWidget);
    repository.requests.last.complete(
      await const _LobbySummaryRepository().fetchCurrentProgress(),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('lobby-loading')), findsOneWidget);
    economy.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lobby-error')), findsNothing);
    expect(find.text('Selesaikan Practice'), findsOneWidget);
  });

  testWidgets(
    'QA-023 reports an economy hydration failure even when progress succeeds',
    (tester) async {
      final progress = PlayerProgressController(
        repository: const _LobbySummaryRepository(),
      );
      await progress.hydrateFromRepository();
      final economy = _LobbyEconomyController()..fail();
      await _pumpLobby(tester, progress, economy);
      expect(find.byKey(const ValueKey('lobby-error')), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.byKey(const ValueKey('lobby-profile-header')), findsNothing);
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(economy.refreshCalls, 1);
      expect(find.byKey(const ValueKey('lobby-error')), findsNothing);
    },
  );

  testWidgets('QA-023 shows honest empty missions and recommendations', (
    tester,
  ) async {
    final repository = _ControlledSummaryRepository();
    final progress = PlayerProgressController(
      repository: repository,
      shouldHydrate: true,
    );
    await _pumpLobby(tester, progress, _LobbyEconomyController());
    repository.requests.single.complete(_emptySummary);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lobby-missions-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lobby-recommendation-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lobby-error')), findsNothing);
    expect(find.text('Daily Question'), findsNothing);
    expect(find.text('Daily PvP'), findsNothing);
    expect(find.textContaining('YCoin'), findsNothing);
    expect(find.byKey(const ValueKey('lobby-quest-roadmap')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA-023 does not fabricate a missing mission or its reward', (
    tester,
  ) async {
    final repository = _ControlledSummaryRepository();
    final progress = PlayerProgressController(
      repository: repository,
      shouldHydrate: true,
    );
    await _pumpLobby(tester, progress, _LobbyEconomyController());
    repository.requests.single.complete(
      const PlayerProgressSnapshot(
        playerId: 'user-1',
        displayName: 'Yudha',
        wins: 0,
        losses: 0,
        draws: 0,
        dailyMissions: [
          {
            'key': 'daily_practice',
            'title': 'Practice dari server',
            'completed': true,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice dari server'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-roadmap-step-pvp')), findsNothing);
    expect(find.byKey(const ValueKey('lobby-roadmap-connector')), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('beta popup waits for server balances and stays acknowledged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BetaSummaryRepository();
    final progress = PlayerProgressController(repository: repository);
    final economy = _BetaEconomyController();
    await progress.hydrateFromRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProgressProvider.overrideWith((ref) => progress),
          playerProgressRepositoryProvider.overrideWithValue(repository),
          gameEconomyProvider.overrideWith((ref) => economy),
        ],
        child: const MaterialApp(home: LobbyPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BetaWelcomeDialog), findsNothing);
    economy.markReady();
    await tester.pumpAndSettle();
    expect(find.byType(BetaWelcomeDialog), findsOneWidget);
    expect(economy.state.energy, 1010);
    await tester.tap(find.text('Mulai Bermain'));
    await tester.pumpAndSettle();
    expect(repository.acknowledged, isTrue);
    await progress.hydrateFromRepository();
    economy.markReady();
    await tester.pumpAndSettle();
    expect(find.byType(BetaWelcomeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('renders the full-blue Lobby and quest roadmap responsively', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final PlayerProgressController progress = PlayerProgressController(
      repository: const _LobbySummaryRepository(),
    );
    await progress.hydrateFromRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProgressProvider.overrideWith((Ref ref) => progress),
          gameEconomyProvider.overrideWith(
            (Ref ref) => _LobbyEconomyController(),
          ),
        ],
        child: const MaterialApp(home: LobbyPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yudha'), findsOneWidget);
    expect(find.text('Win rate'), findsNothing);
    expect(find.text('RANKED MATCH'), findsNothing);
    expect(find.text('Poin Rank'), findsOneWidget);
    expect(find.text('Streak belajar'), findsOneWidget);
    expect(find.text('CPNS'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('8 dari 19 skill memiliki bukti cukup'), findsOneWidget);
    expect(find.text('MISI HARI INI'), findsOneWidget);
    expect(find.text('START BATTLE'), findsOneWidget);
    expect(find.text('XP to next rank'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('lobby-profile-background')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-mission-background')),
      findsOneWidget,
    );
    final ColoredBox profileBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('lobby-profile-background')),
    );
    final ColoredBox missionBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('lobby-mission-background')),
    );
    final DecoratedBox profileClayBase = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('lobby-profile-clay-base')),
    );
    final ClipRRect profileClip = tester.widget<ClipRRect>(
      find.byKey(const ValueKey<String>('lobby-profile-clip')),
    );
    expect(profileBackground.color, const Color(0xFF0D49B5));
    expect(
      profileClip.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(26)),
    );
    expect(
      profileClayBase.decoration,
      const BoxDecoration(
        color: Color(0xFF06378F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
    );
    final AppBar lobbyAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(lobbyAppBar.backgroundColor, const Color(0xFF0D49B5));
    expect(lobbyAppBar.centerTitle, isFalse);
    expect(lobbyAppBar.titleSpacing, 20);
    expect(missionBackground.color, AppColors.scholarCream);
    final Rect profileBackgroundRect = tester.getRect(
      find.byKey(const ValueKey<String>('lobby-profile-background')),
    );
    final Rect profileClayBaseRect = tester.getRect(
      find.byKey(const ValueKey<String>('lobby-profile-clay-base')),
    );
    final Rect missionBackgroundRect = tester.getRect(
      find.byKey(const ValueKey<String>('lobby-mission-background')),
    );
    expect(
      profileBackgroundRect.bottom + 8,
      closeTo(missionBackgroundRect.top, 0.1),
    );
    expect(profileClayBaseRect.bottom, missionBackgroundRect.top);
    expect(
      profileClayBaseRect.height /
          (profileClayBaseRect.height + missionBackgroundRect.height),
      closeTo(0.4, 0.001),
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-profile-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-swords-watermark')),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey<String>('lobby-profile-content')),
          )
          .dy,
      closeTo(profileBackgroundRect.center.dy - 11, 0.1),
    );
    expect(find.byKey(const ValueKey<String>('lobby-hero-base')), findsNothing);
    expect(find.byKey(const ValueKey<String>('lobby-hero-face')), findsNothing);

    expect(
      find.byKey(const ValueKey<String>('lobby-hero-identity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-hero-stats-panel')),
      findsOneWidget,
    );
    final Container identityPanel = tester.widget<Container>(
      find.byKey(const ValueKey<String>('lobby-profile-identity-panel')),
    );
    expect(
      (identityPanel.decoration! as BoxDecoration).color,
      Colors.white.withAlpha(13),
    );
    expect(
      identityPanel.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    expect(
      find.byKey(const ValueKey<String>('lobby-rank-points')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-hero-stat-win-rate')),
      findsNothing,
    );

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('lobby-hero-identity')))
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('lobby-hero-stats-panel')),
            )
            .dy,
      ),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-hero-stats-panel')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('lobby-hero-identity')),
              )
              .dy,
      closeTo(16, 0.1),
    );

    final Container roadmap = tester.widget<Container>(
      find.byKey(const ValueKey<String>('lobby-quest-roadmap')),
    );
    expect((roadmap.decoration! as BoxDecoration).color, Colors.white);
    expect(roadmap.padding, const EdgeInsets.fromLTRB(24, 22, 24, 20));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('lobby-roadmap-step-practice')),
          )
          .height,
      90,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('lobby-roadmap-node-practice')),
      ),
      const Size.square(60),
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-roadmap-connector')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('lobby-roadmap-connector')),
          )
          .height,
      36,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-floating-board')),
      findsOneWidget,
    );
    final DecoratedBox boardBase = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('lobby-floating-board-base')),
    );
    expect(
      (boardBase.decoration as BoxDecoration).color,
      const Color(0xFFD1D5DC),
    );

    final DecoratedBox battleBase = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('lobby-start-battle-base')),
    );
    expect(
      (battleBase.decoration as BoxDecoration).color,
      const Color(0xFFF2A45E),
    );
    final Material battleFace = tester.widget<Material>(
      find.byKey(const ValueKey<String>('lobby-start-battle-face')),
    );
    expect(battleFace.color, const Color(0xFFFFD8A6));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('lobby-floating-board')),
        matching: find.byKey(const ValueKey<String>('lobby-start-battle')),
      ),
      findsOneWidget,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-quest-roadmap')),
              )
              .dx -
          tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-mission-background')),
              )
              .dx,
      closeTo(24, 0.1),
    );
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey('lobby-recommendation-empty')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('lobby-floating-board')))
            .dy,
      ),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-start-battle')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('lobby-roadmap-step-pvp')),
              )
              .dy,
      closeTo(28, 0.1),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('lobby-start-battle')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey<String>('lobby-start-battle')),
          )
          .dy,
      lessThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey<String>('lobby-mission-background')),
            )
            .dy,
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 680));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('lobby-quest-roadmap')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('lobby-start-battle')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('lobby-roadmap-step-practice')),
          )
          .height,
      80,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('lobby-roadmap-node-practice')),
      ),
      const Size.square(54),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('lobby-roadmap-connector')),
          )
          .height,
      28,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-start-battle')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('lobby-roadmap-step-pvp')),
              )
              .dy,
      closeTo(22, 0.1),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('lobby-start-battle')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('lobby-start-battle'))).dy,
      lessThanOrEqualTo(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('lobby-mission-background')),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey<String>('lobby-profile-content')),
          )
          .dy,
      closeTo(
        tester
                .getCenter(
                  find.byKey(
                    const ValueKey<String>('lobby-profile-background'),
                  ),
                )
                .dy -
            8,
        0.1,
      ),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('lobby-hero-stats-panel')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey<String>('lobby-hero-identity')),
              )
              .dy,
      closeTo(12, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the recommendation with evidence strength', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final PlayerProgressController progress = PlayerProgressController(
      repository: const _LearningProgressRepository(),
    );
    await progress.hydrateFromRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProgressProvider.overrideWith((Ref ref) => progress),
          gameEconomyProvider.overrideWith(
            (Ref ref) => _LobbyEconomyController(),
          ),
          learningRepositoryProvider.overrideWithValue(
            const _LobbyLearningRepository(),
          ),
        ],
        child: const MaterialApp(home: LobbyPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('lobby-learning-recommendation')),
      findsOneWidget,
    );
    expect(find.text('TIU Numerik'), findsOneWidget);
    expect(find.textContaining('kekuatan bukti sedang'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays scroll-safe inside the web tab shell', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProgressProvider.overrideWith((Ref ref) {
            final PlayerProgressController controller =
                PlayerProgressController(
                  repository: const _LobbySummaryRepository(
                    withCoverage: false,
                  ),
                  shouldHydrate: true,
                );
            return controller;
          }),
          gameEconomyProvider.overrideWith(
            (Ref ref) => _LobbyEconomyController(),
          ),
        ],
        child: const MaterialApp(
          home: AppTabShell(location: AppRoutes.lobby, child: LobbyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('lobby-mission-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('Data cakupan belum tersedia'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('START BATTLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _emptySummary = PlayerProgressSnapshot(
  playerId: 'user-1',
  displayName: 'Yudha',
  wins: 0,
  losses: 0,
  draws: 0,
);

Future<void> _pumpLobby(
  WidgetTester tester,
  PlayerProgressController progress,
  GameEconomyController economy,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerProgressProvider.overrideWith((ref) => progress),
        gameEconomyProvider.overrideWith((ref) => economy),
      ],
      child: const MaterialApp(home: LobbyPage()),
    ),
  );
  await tester.pump();
}

class _ControlledSummaryRepository extends PlayerProgressRepository {
  final requests = <Completer<PlayerProgressSnapshot>>[];
  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() {
    final request = Completer<PlayerProgressSnapshot>();
    requests.add(request);
    return request.future;
  }
}

class _LobbyEconomyController extends GameEconomyController {
  _LobbyEconomyController() {
    markReady();
  }
  int refreshCalls = 0;
  Completer<void>? pending;
  void markReady() {
    state = state.copyWith(
      syncStatus: EconomySyncStatus.synced,
      dataSource: EconomyDataSource.server,
    );
  }

  void fail() {
    state = state.copyWith(syncStatus: EconomySyncStatus.syncUnavailable);
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
    state = state.copyWith(syncStatus: EconomySyncStatus.loading);
    await pending?.future;
    markReady();
  }
}

class _LearningProgressRepository extends PlayerProgressRepository {
  const _LearningProgressRepository();

  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async {
    return PlayerProgressSnapshot(
      playerId: 'user-1',
      displayName: 'Yudha',
      wins: 1,
      losses: 0,
      draws: 0,
      learningNextAction: LearningRecommendation.fromJson(<String, dynamic>{
        'recommendationId': 'recommendation-1',
        'target': 'cpns',
        'objective': 'repair_accuracy',
        'skill': <String, dynamic>{
          'id': 'cpns.tiu.numerik',
          'label': 'TIU Numerik',
          'category': 'tiu',
          'subcategory': 'numerik',
        },
        'mechanicMode': 'focus',
        'reason': <String, dynamic>{
          'headline': 'Perkuat TIU Numerik',
          'description': 'Bukti terbaru menunjukkan ruang perbaikan.',
        },
        'confidence': 'medium',
        'availability': <String, dynamic>{
          'runnable': true,
          'compatibilityAdapter': 'practice_fixed_five',
          'label': 'Practice 5 soal (kompatibilitas)',
        },
      }),
    );
  }
}

class _LobbySummaryRepository extends PlayerProgressRepository {
  const _LobbySummaryRepository({this.withCoverage = true});
  final bool withCoverage;

  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async {
    return PlayerProgressSnapshot(
      playerId: 'user-1',
      displayName: 'Yudha',
      totalPoints: 1050,
      tier: 'elite',
      target: 'cpns',
      wins: 12,
      losses: 4,
      draws: 1,
      streak: 7,
      dailyMissions: const [
        {
          'key': 'daily_practice',
          'title': 'Selesaikan Practice',
          'completed': false,
          'rewardYCoins': 0,
        },
        {
          'key': 'daily_pvp',
          'title': 'Selesaikan PvP publik',
          'completed': false,
          'rewardYCoins': 0,
        },
      ],
      curriculumCoverage: withCoverage
          ? const LearningCoverage(
              value: 42,
              coveredSkillCount: 8,
              requiredSkillCount: 19,
              confidence: 'medium',
            )
          : null,
    );
  }
}

class _BetaSummaryRepository extends PlayerProgressRepository {
  bool acknowledged = false;
  @override
  Future<void> acknowledgeBetaWelcome() async {
    acknowledged = true;
  }

  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async =>
      PlayerProgressSnapshot(
        playerId: 'beta-user',
        displayName: 'Beta User',
        wins: 0,
        losses: 0,
        draws: 0,
        betaWelcomeReward: BetaWelcomeReward(
          id: 'reward-1',
          coinAmount: 1000,
          energyAmount: 1000,
          acknowledgedAt: acknowledged ? '2026-09-11T00:00:00Z' : null,
        ),
      );
}

class _BetaEconomyController extends GameEconomyController {
  void markReady() {
    state = state.copyWith(
      energy: 1010,
      yCoins: 1000,
      maxEnergy: 10,
      syncStatus: EconomySyncStatus.synced,
      dataSource: EconomyDataSource.server,
    );
  }
}

class _LobbyLearningRepository implements LearningRepository {
  const _LobbyLearningRepository();

  @override
  Future<LearningDashboard> fetchDashboard() {
    throw StateError('Lobby does not need the dashboard payload.');
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}
