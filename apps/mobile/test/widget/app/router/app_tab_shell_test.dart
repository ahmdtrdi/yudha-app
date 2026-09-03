import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/app/router/app_tab_shell.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_setup_page.dart';

void main() {
  testWidgets('hides navigation during an active Solo session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.soloSession,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('app-tab-capsule')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('app-tab-clay-base')),
      findsNothing,
    );
  });

  testWidgets('renders the new icon-only navigation order', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.learning,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('app-tab-capsule')), findsOne);
    expect(find.byKey(const ValueKey<String>('app-tab-clay-base')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('app-tab-indicator-Learning Center')),
      findsOne,
    );
    expect(find.text('Lobby'), findsNothing);
    expect(find.text('Leaderboard'), findsNothing);
    expect(find.text('Learning'), findsNothing);
    expect(find.text('Learning Center'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsOne);

    final ColoredBox background = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('app-tab-background')),
    );
    expect(background.color, AppColors.scholarCream);
    final Rect capsuleRect = tester.getRect(
      find.byKey(const ValueKey<String>('app-tab-capsule')),
    );
    final Rect learningButtonRect = tester.getRect(
      find.byKey(const ValueKey<String>('learning-tab-button')),
    );
    expect(learningButtonRect.top, lessThan(capsuleRect.top));
    expect(learningButtonRect.bottom, greaterThan(capsuleRect.bottom - 16));

    final SemanticsNode learningSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('app-tab-Learning Center')),
    );
    expect(
      learningSemantics.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
  });

  testWidgets('opens a labeled radial Learning menu and dismisses it', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.lobby,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('learning-menu')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('app-tab-Learning')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('learning-menu')), findsOne);
    expect(find.text('Solo'), findsOne);
    expect(find.text('PvP'), findsOne);
    expect(find.text('Interview'), findsOne);
    expect(
      find.byKey(const ValueKey<String>('learning-menu-shared-glow')),
      findsOne,
    );
    final DecoratedBox sharedGlow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('learning-menu-shared-glow')),
    );
    final RadialGradient sharedGradient =
        (sharedGlow.decoration as BoxDecoration).gradient! as RadialGradient;
    expect(sharedGradient.center, const Alignment(0, 1.35));
    final ModalBarrier barrier = tester.widget<ModalBarrier>(
      find.byKey(const ValueKey<String>('learning-menu-barrier')),
    );
    expect(barrier.color, Colors.transparent);
    final List<Color> actionColors = <String>['Solo', 'PvP', 'Interview']
        .map(
          (String label) => tester
              .widget<Material>(
                find.byKey(ValueKey<String>('learning-menu-surface-$label')),
              )
              .color!,
        )
        .toList(growable: false);
    expect(actionColors.toSet(), hasLength(3));
    final Rect menuRect = tester.getRect(
      find.byKey(const ValueKey<String>('learning-menu')),
    );
    final Rect capsuleRect = tester.getRect(
      find.byKey(const ValueKey<String>('app-tab-capsule')),
    );
    expect(menuRect.bottom, lessThan(capsuleRect.top));

    final SemanticsNode learningSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('app-tab-Learning')),
    );
    expect(
      learningSemantics.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );

    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('learning-menu')), findsNothing);
  });

  testWidgets('animates Learning actions out of the center button', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.lobby,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    final Offset origin = tester.getCenter(
      find.byKey(const ValueKey<String>('learning-tab-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('app-tab-Learning')));
    await tester.pump();
    final Offset openingSolo = tester.getCenter(
      find.byKey(const ValueKey<String>('learning-menu-surface-Solo')),
    );
    await tester.pump(const Duration(milliseconds: 160));
    final Offset midSolo = tester.getCenter(
      find.byKey(const ValueKey<String>('learning-menu-surface-Solo')),
    );
    await tester.pumpAndSettle();
    final Offset finalSolo = tester.getCenter(
      find.byKey(const ValueKey<String>('learning-menu-surface-Solo')),
    );

    expect(
      (openingSolo - origin).distance,
      lessThan((midSolo - origin).distance),
    );
    expect(
      (finalSolo - origin).distance,
      greaterThan((openingSolo - origin).distance),
    );
    expect((midSolo - finalSolo).distance, greaterThan(1));

    await tester.tapAt(const Offset(20, 100));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey<String>('learning-menu')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('learning-menu')), findsNothing);
  });

  testWidgets('opens the Solo setup from the Learning menu', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.lobby,
      routes: <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return AppTabShell(location: state.uri.path, child: child);
          },
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.lobby,
              builder: (_, _) => const ColoredBox(color: Colors.white),
            ),
            GoRoute(
              path: AppRoutes.solo,
              builder: (_, _) => const SoloSetupPage(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('app-tab-Learning')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('learning-menu-surface-Solo')),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.solo);
    expect(find.text('SESI UNTUKMU'), findsOneWidget);
  });
}
