import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/data/repositories/backend_learning_repository.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/learning/presentation/pages/learning_page.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_launch_request.dart';

void main() {
  testWidgets('shows a skeleton on first load', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(_PendingRepository()),
        ],
        child: const MaterialApp(home: LearningPage()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('learning-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('remains readable with larger text on a narrow viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(
            const _ReadyLearningRepository(),
          ),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const LearningPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('learning-insights')),
      250,
    );

    expect(tester.takeException(), isNull);
  });

  for (final Size size in <Size>[const Size(360, 760), const Size(700, 900)]) {
    testWidgets(
      'renders Learning sections without turning null into zero at $size',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              learningRepositoryProvider.overrideWithValue(
                const _ReadyLearningRepository(),
              ),
            ],
            child: const MaterialApp(home: LearningPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('learning-dashboard')),
          findsOneWidget,
        );
        expect(find.text('Ringkasan kemajuan'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('learning-insights')),
          250,
        );
        expect(
          find.byKey(const ValueKey<String>('learning-insights')),
          findsOneWidget,
        );
        expect(find.text('—'), findsWidgets);
        expect(find.textContaining('0% akurasi mandiri'), findsNothing);
        expect(
          find.text('Mengumpulkan data · 0/1 · bukti rendah'),
          findsOneWidget,
        );
        expect(find.textContaining('Perlu diperbaiki'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('opens drill-down detail for a skill', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(
            const _ReadyLearningRepository(),
          ),
        ],
        child: const MaterialApp(home: LearningPage()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder skill = find.byKey(
      const ValueKey<String>('learning-skill-cpns.twk'),
    );
    await tester.dragUntilVisible(
      skill,
      find.byKey(const ValueKey<String>('learning-dashboard')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(skill);
    await tester.pumpAndSettle();

    expect(find.text('Akurasi mandiri'), findsWidgets);
    expect(find.textContaining('Mode yang disarankan:'), findsOneWidget);
    expect(find.text('Latih TWK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records recommendation once and hands topic/id to Practice', (
    WidgetTester tester,
  ) async {
    final _RecommendationRepository repository = _RecommendationRepository();
    final GoRouter router = GoRouter(
      initialLocation: '/learning',
      routes: <RouteBase>[
        GoRoute(path: '/learning', builder: (_, _) => const LearningPage()),
        GoRoute(
          path: '/solo/topics',
          builder: (_, GoRouterState state) {
            final PracticeLaunchRequest request =
                state.extra! as PracticeLaunchRequest;
            return Scaffold(
              body: Text('${request.focus}|${request.recommendationId}'),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();

    expect(
      repository.events.where((String value) => value == 'shown'),
      hasLength(1),
    );
    await tester.tap(find.text('Mulai Practice 5 soal'));
    await tester.pumpAndSettle();

    expect(
      repository.events.where((String value) => value == 'accepted'),
      hasLength(1),
    );
    expect(find.text('numerik|recommendation-1'), findsOneWidget);
  });

  testWidgets('explains an unavailable recommendation without navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(
            const _ReadyLearningRepository(
              includeRecommendation: true,
              recommendationRunnable: false,
            ),
          ),
        ],
        child: const MaterialApp(home: LearningPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Persediaan soal belum mencukupi.'), findsOneWidget);
    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Belum dapat dijalankan'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows a rollout-safe unavailable state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(
            const _UnavailableLearningRepository(),
          ),
        ],
        child: const MaterialApp(home: LearningPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning segera hadir'), findsOneWidget);
    expect(find.text('Buka Practice'), findsOneWidget);
  });

  testWidgets('explains evidence strength with the learner numbers', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          learningRepositoryProvider.overrideWithValue(
            const _ReadyLearningRepository(),
          ),
        ],
        child: const MaterialApp(home: LearningPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Apa artinya?').first);
    await tester.pumpAndSettle();

    expect(find.text('Kekuatan bukti'), findsOneWidget);
    expect(find.text('Yang dihitung'), findsOneWidget);
    expect(find.text('Yang tidak dihitung'), findsOneWidget);
    expect(find.text('Rumus'), findsOneWidget);
    expect(find.text('Contoh dari datamu'), findsOneWidget);
    expect(find.text('Jendela bukti'), findsOneWidget);
    expect(
      find.textContaining(
        'Totalmu 0 percobaan dari 0 soal unik. Kekuatan ringkasan rendah',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ReadyLearningRepository implements LearningRepository {
  const _ReadyLearningRepository({
    this.includeRecommendation = false,
    this.recommendationRunnable = true,
  });

  final bool includeRecommendation;
  final bool recommendationRunnable;

  @override
  Future<LearningDashboard> fetchDashboard() async {
    return LearningDashboard.fromJson(<String, dynamic>{
      'asOf': '2026-09-01T02:00:00.000Z',
      'calculationVersion': 'learning-v1',
      'target': 'cpns',
      'nextAction': includeRecommendation
          ? <String, dynamic>{
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
                'description': 'Akurasi perlu diperbaiki.',
              },
              'confidence': 'medium',
              'availability': <String, dynamic>{
                'runnable': recommendationRunnable,
                'reason': recommendationRunnable
                    ? null
                    : 'Persediaan soal belum mencukupi.',
                'compatibilityAdapter': 'practice_fixed_five',
                'label': 'Practice 5 soal',
              },
            }
          : null,
      'summary': <String, dynamic>{
        'curriculumCoverage': <String, dynamic>{
          'value': null,
          'coveredSkillCount': 0,
          'requiredSkillCount': 4,
          'confidence': 'low',
        },
        'unseenIndependentAccuracy': <String, dynamic>{
          'value': null,
          'correctCount': 0,
          'attemptCount': 0,
          'uniqueQuestionCount': 0,
          'confidence': 'low',
          'asOf': '2026-09-01T02:00:00.000Z',
        },
        'pace': <String, dynamic>{
          'value': null,
          'baselineType': null,
          'attemptCount': 0,
          'confidence': 'low',
        },
      },
      'skillStates': <Map<String, dynamic>>[
        <String, dynamic>{
          'skillId': 'cpns.twk',
          'label': 'TWK',
          'category': 'twk',
          'status': 'needs_repair',
          'evidenceConfidence': 'low',
          'unseenIndependentAccuracy': <String, dynamic>{
            'value': 0,
            'correctCount': 0,
            'attemptCount': 1,
            'uniqueQuestionCount': 1,
            'confidence': 'low',
          },
        },
      ],
      'trends': <dynamic>[],
      'retention': <dynamic>[],
      'assessment': <String, dynamic>{'status': 'not_available'},
      'activity': <String, dynamic>{
        'activeLearningDays': 1,
        'questionsAnswered': 1,
        'activeLearningMinutes': null,
        'sessionCount': 1,
      },
      'competition': <String, dynamic>{
        'separateEvidenceContext': true,
        'accuracy': <String, dynamic>{
          'value': null,
          'correctCount': 0,
          'attemptCount': 0,
          'confidence': null,
          'asOf': '2026-09-01T02:00:00.000Z',
        },
      },
    });
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}

class _RecommendationRepository extends _ReadyLearningRepository {
  _RecommendationRepository() : super(includeRecommendation: true);

  final List<String> events = <String>[];

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {
    expect(recommendationId, 'recommendation-1');
    events.add(eventType);
  }
}

class _UnavailableLearningRepository implements LearningRepository {
  const _UnavailableLearningRepository();

  @override
  Future<LearningDashboard> fetchDashboard() {
    throw const LearningUnavailableException();
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}

class _PendingRepository implements LearningRepository {
  final Completer<LearningDashboard> _completer =
      Completer<LearningDashboard>();

  @override
  Future<LearningDashboard> fetchDashboard() => _completer.future;

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}
