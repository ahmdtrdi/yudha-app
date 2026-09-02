import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_loadout_page.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_setup_page.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.solo,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.solo, builder: (_, _) => const SoloSetupPage()),
        GoRoute(
          path: AppRoutes.soloLoadout,
          builder: (_, _) => const SoloLoadoutPage(),
        ),
      ],
    );
  }

  Future<void> pumpSolo(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the playable Solo preset and continues to loadout', (
    WidgetTester tester,
  ) async {
    await pumpSolo(tester);

    expect(find.text('SESI UNTUKMU'), findsOneWidget);
    expect(find.text('Rimba Yudha'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Seimbang'), findsOneWidget);
    expect(find.text('20 soal'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('solo-recommended-arena-preview')),
      findsOneWidget,
    );
    expect(find.text('CARA LATIHAN'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('solo-manual-sheet')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('solo-recommended-continue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('PILIH KARAKTER'), findsWidgets);
    expect(find.text('Standard · Seimbang · 20 soal'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('solo-mode-arena-auto')),
      findsOneWidget,
    );
  });

  testWidgets('opens an unselected manual sheet and applies its choices', (
    WidgetTester tester,
  ) async {
    await pumpSolo(tester);

    await tester.tap(find.byKey(const ValueKey<String>('solo-open-manual')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('solo-manual-sheet')),
      findsOneWidget,
    );
    expect(find.text('CARA LATIHAN'), findsOneWidget);
    expect(find.text('JUMLAH SOAL'), findsOneWidget);
    expect(find.text('MATERI'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey<String>('solo-mechanic-card-standard')),
          )
          .properties
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey<String>('solo-question-count-card-20')),
          )
          .properties
          .selected,
      isFalse,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('solo-mechanic-card-standard')),
          )
          .height,
      tester
          .getSize(
            find.byKey(const ValueKey<String>('solo-question-count-card-20')),
          )
          .height,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('solo-mechanic-standard')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('solo-question-count-35')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Standard · Seimbang · 35 soal'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('solo-mode-arena-balanced')),
      findsOneWidget,
    );
  });

  testWidgets('keeps unavailable mechanic and recommendation cards disabled', (
    WidgetTester tester,
  ) async {
    await pumpSolo(tester);
    await tester.tap(find.byKey(const ValueKey<String>('solo-open-manual')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-mechanic-focus')),
          )
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-mode-recommended')),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('manual sheet remains scroll-safe on a short viewport', (
    WidgetTester tester,
  ) async {
    await pumpSolo(tester, size: const Size(390, 680));
    await tester.tap(find.byKey(const ValueKey<String>('solo-open-manual')));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const ValueKey<String>('solo-manual-sheet')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('solo-setup-continue')),
      findsOneWidget,
    );
  });
}
