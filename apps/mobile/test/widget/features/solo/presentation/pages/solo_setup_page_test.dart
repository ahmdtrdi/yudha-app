import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_loadout_page.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_setup_page.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class _TestRecommendationRepository implements LearningRepository {
  @override
  Future<LearningDashboard> fetchDashboard() async {
    return LearningDashboard.fromJson(<String, dynamic>{
      'asOf': '2026-09-01T02:00:00.000Z',
      'calculationVersion': 'learning-v2',
      'target': 'cpns',
      'nextAction': <String, dynamic>{
        'recommendationId': 'rec-12345',
        'target': 'cpns',
        'objective': 'strengthen_evidence',
        'skill': <String, dynamic>{
          'id': 'tiu-figural',
          'label': 'TIU Figural',
          'category': 'tiu',
          'subcategory': 'Figural',
        },
        'mechanicMode': 'standard',
        'reason': <String, dynamic>{
          'headline': 'Kumpulkan bukti belajar: TIU Figural',
          'description': 'Data untuk TIU Figural masih dikumpulkan...',
        },
        'confidence': 'low',
        'availability': <String, dynamic>{
          'runnable': true,
        },
      },
      'summary': <String, dynamic>{},
      'skillStates': <dynamic>[],
      'trends': <dynamic>[],
      'retention': <dynamic>[],
      'assessment': <String, dynamic>{'status': 'not_available'},
      'activity': <String, dynamic>{},
      'competition': <String, dynamic>{},
    });
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}

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
    List<Override> overrides = const <Override>[],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('manual mode overrides recommendation and survives refresh', (
    WidgetTester tester,
  ) async {
    await pumpSolo(tester, overrides: <Override>[
      learningRepositoryProvider.overrideWithValue(_TestRecommendationRepository()),
    ]);
    final container = ProviderScope.containerOf(tester.element(find.byType(SoloSetupPage)));
    expect(container.read(soloSetupControllerProvider).mode, SoloSetupMode.recommended);

    await tester.tap(find.byKey(const ValueKey<String>('solo-open-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    expect(container.read(soloSetupControllerProvider).mode, SoloSetupMode.balanced);
    expect(container.read(soloSetupControllerProvider).recommendationId, isNull);

    await container.read(learningControllerProvider.notifier).load();
    await tester.pumpAndSettle();
    expect(container.read(soloSetupControllerProvider).mode, SoloSetupMode.balanced);

    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-recommended')));
    await tester.pumpAndSettle();
    expect(container.read(soloSetupControllerProvider).recommendationId, 'rec-12345');
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Standard · Seimbang · 20 soal'), findsWidgets);
  });

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

  testWidgets('allows selecting focus and speed mechanics and recommended mode', (
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
      isNotNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-mechanic-speed')),
          )
          .onTap,
      isNotNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('solo-mode-recommended')),
          )
          .onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey<String>('solo-mechanic-focus')));
    await tester.tap(find.byKey(const ValueKey<String>('solo-question-count-20')));
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-balanced')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('solo-setup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Focus · Seimbang · 20 soal'), findsWidgets);
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

  testWidgets('automatically loads learning recommendation as default Solo preset', (
    WidgetTester tester,
  ) async {
    final fakeRepo = _TestRecommendationRepository();
    await pumpSolo(
      tester,
      overrides: <Override>[
        learningRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );

    expect(find.text('TIU Figural'), findsWidgets);
    expect(find.text('Standard'), findsWidgets);
    expect(find.text('MAIN SESI REKOMENDASI'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('solo-recommended-continue')));
    await tester.pumpAndSettle();

    expect(find.textContaining('TIU Figural (Rekomendasi)'), findsWidgets);
  });
  testWidgets('editing recommendation switches to custom and reselecting restores preset', (tester) async {
    await pumpSolo(tester, overrides: [learningRepositoryProvider.overrideWithValue(_TestRecommendationRepository())]);
    final container = ProviderScope.containerOf(tester.element(find.byType(SoloSetupPage)));
    await tester.tap(find.byKey(const ValueKey<String>('solo-open-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('solo-mechanic-speed')));
    await tester.pumpAndSettle();
    var state = container.read(soloSetupControllerProvider);
    expect(state.mode, SoloSetupMode.custom);
    expect(state.legacyTopic, isNull);
    expect(state.recommendationId, isNull);
    expect(state.mechanicMode, SoloMechanicMode.speed);
    await tester.tap(find.byKey(const ValueKey<String>('solo-mode-recommended')));
    await tester.pumpAndSettle();
    state = container.read(soloSetupControllerProvider);
    expect(state.mode, SoloSetupMode.recommended);
    expect(state.mechanicMode, SoloMechanicMode.standard);
    expect(state.questionCount, SoloQuestionCount.twenty);
    expect(state.recommendationId, 'rec-12345');
    await tester.tap(find.byKey(const ValueKey<String>('solo-question-count-35')));
    await tester.pumpAndSettle();
    expect(container.read(soloSetupControllerProvider).mode, SoloSetupMode.custom);
    expect(container.read(soloSetupControllerProvider).legacyTopic, isNull);
  });

  testWidgets('manual entry opens the setup sheet immediately', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SoloSetupPage(openManual: true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('solo-manual-sheet')), findsOneWidget);
  });
}
