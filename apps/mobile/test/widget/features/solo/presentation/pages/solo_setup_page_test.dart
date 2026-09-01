import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_loadout_page.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_setup_page.dart';

void main() {
  testWidgets('selects Balanced and opens the clay Solo loadout', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
        GoRoute(
          path: AppRoutes.soloLoadout,
          builder: (_, _) => const SoloLoadoutPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('LATIHAN SOLO'), findsOneWidget);
    expect(find.text('SESI UNTUKMU'), findsOneWidget);
    expect(find.text('ATUR SENDIRI'), findsOneWidget);
    expect(find.text('CARA LATIHAN'), findsOneWidget);
    expect(find.text('MATERI'), findsOneWidget);
    expect(find.text('Mau latihan seperti apa?'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('solo-top-bar-depth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-recommended-arena-preview')),
      findsOneWidget,
    );
    expect(find.text('UTAMA'), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.text('Auto'), findsNothing);
    expect(find.text('Seimbang'), findsOneWidget);
    expect(find.text('Rekomendasi'), findsNWidgets(2));
    expect(find.text('Pilih topik'), findsOneWidget);
    expect(find.text('Tanpa waktu'), findsOneWidget);
    expect(find.text('Tempo normal'), findsOneWidget);
    expect(find.text('Lebih cepat'), findsOneWidget);
    expect(find.text('Semua materi'), findsOneWidget);
    expect(find.text('Topik terlemah'), findsOneWidget);
    expect(find.text('Atur materi'), findsOneWidget);
    for (final String mode in <String>['balanced', 'recommended', 'custom']) {
      expect(
        find.byKey(ValueKey<String>('solo-mode-arena-preview-$mode')),
        findsOneWidget,
      );
    }

    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey<String>('solo-setup-continue')),
          )
          .dy,
      lessThan(744),
    );
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('PILIH KARAKTER'), findsWidgets);
    expect(find.text('SIAPKAN SOLO'), findsNothing);
    expect(find.text('PREVIEW'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('solo-loadout-summary')),
      findsOneWidget,
    );
    expect(find.text('Focus · Seimbang'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('solo-mode-arena-balanced')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-selected-character')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-character-ground-shadow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-character-list')),
      findsOneWidget,
    );
    final Rect stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('solo-character-stage')),
    );
    expect(stageRect.width / stageRect.height, closeTo(1.05, 0.02));
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('solo-character-character-basic-squire'),
            ),
          )
          .width,
      100,
    );
    expect(
      find.ancestor(
        of: find.byKey(
          const ValueKey<String>('solo-character-art-character-basic-pip'),
        ),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey<String>('solo-start-preview')),
          )
          .dy,
      lessThan(744),
    );
  });

  testWidgets('manual controls leave the recommended session', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-auto')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey<String>('solo-recommended-action-icon')),
          )
          .icon,
      Icons.check_rounded,
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey<String>('solo-setup-button-surface')),
          )
          .color,
      const Color(0xFFE6E8EC),
    );
    for (final String mechanic in <String>['focus', 'standard', 'speed']) {
      expect(
        tester
            .widget<Semantics>(
              find.byKey(ValueKey<String>('solo-mechanic-card-$mechanic')),
            )
            .properties
            .selected,
        isFalse,
      );
    }

    await tester.tap(find.byKey(const ValueKey<String>('solo-mechanic-speed')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey<String>('solo-recommended-action-icon')),
          )
          .icon,
      Icons.arrow_forward_rounded,
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey<String>('solo-mechanic-card-speed')),
          )
          .properties
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-setup-continue')),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('selects pace before opening the character loadout', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
        GoRoute(
          path: AppRoutes.soloLoadout,
          builder: (_, _) => const SoloLoadoutPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-mechanic-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Speed · Seimbang'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('solo-mechanic-selector')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('solo-start-preview')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('solo-start-preview')));
    await tester.pump();
    expect(
      find.text('Setup tersimpan. Sesi Solo belum diaktifkan pada commit ini.'),
      findsOneWidget,
    );
  });

  testWidgets('resets mode selection after leaving the Solo flow', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.lobby, builder: (_, _) => const SizedBox()),
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-setup-continue')),
          )
          .onTap,
      isNotNull,
    );

    router.go(AppRoutes.lobby);
    await tester.pumpAndSettle();
    router.go(AppRoutes.solo);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-setup-continue')),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('resets mode selection when returning from loadout', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
        GoRoute(
          path: AppRoutes.soloLoadout,
          builder: (_, _) => const SoloLoadoutPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-loadout-back')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-setup-continue')),
          )
          .onTap,
      isNull,
    );
  });
}
