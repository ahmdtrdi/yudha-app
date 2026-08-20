import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/lobby/presentation/pages/lobby_page.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

void main() {
  testWidgets('renders the full-blue Lobby and quest roadmap responsively', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProgressProvider.overrideWith((Ref ref) {
            final PlayerProgressController controller =
                PlayerProgressController();
            controller.setDisplayName('Yudha');
            controller.applyBattleResult(
              outcome: BattleOutcome.win,
              ratingDelta: 1050,
            );
            return controller;
          }),
          gameEconomyProvider.overrideWith(
            (Ref ref) => GameEconomyController(),
          ),
        ],
        child: const MaterialApp(home: LobbyPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yudha'), findsOneWidget);
    expect(find.text('Win rate'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('RANK POINTS'), findsOneWidget);
    expect(find.text('Menuju tier berikutnya'), findsOneWidget);
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
      find.byKey(const ValueKey<String>('lobby-hero-primary-points')),
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
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('lobby-hero-rank-progress')),
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
      closeTo(32, 0.1),
    );

    final Container tierBadge = tester.widget<Container>(
      find.byKey(const ValueKey<String>('lobby-hero-tier-badge')),
    );
    expect(
      (tierBadge.decoration! as BoxDecoration).color,
      const Color(0xFFFFD9B5),
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
          .getCenter(find.byKey(const ValueKey<String>('lobby-floating-board')))
          .dy,
      closeTo(missionBackgroundRect.center.dy, 0.1),
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
    expect(
      tester
          .getCenter(find.byKey(const ValueKey<String>('lobby-floating-board')))
          .dy,
      closeTo(
        tester
            .getCenter(
              find.byKey(const ValueKey<String>('lobby-mission-background')),
            )
            .dy,
        0.1,
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
      closeTo(26, 0.1),
    );
    expect(tester.takeException(), isNull);
  });
}
