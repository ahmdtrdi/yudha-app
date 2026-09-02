import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/data/repositories/backend_learning_repository.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/learning/presentation/pages/learning_page.dart';

void main() {
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
        expect(find.text('Ringkasan belajar'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
        expect(find.textContaining('0% akurasi mandiri'), findsNothing);
        expect(
          find.textContaining('Mengumpulkan data · 1 bukti mandiri'),
          findsOneWidget,
        );
        expect(find.textContaining('Kekuatan bukti rendah'), findsWidgets);
        expect(find.text('Perlu diperbaiki · 1 bukti mandiri'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
  const _ReadyLearningRepository();

  @override
  Future<LearningDashboard> fetchDashboard() async {
    return LearningDashboard.fromJson(<String, dynamic>{
      'asOf': '2026-09-01T02:00:00.000Z',
      'calculationVersion': 'learning-v1',
      'target': 'cpns',
      'nextAction': null,
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
