import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';

class _SuccessPracticeRepository implements PracticeRepository {
  const _SuccessPracticeRepository();

  static const PracticeTopic topic = PracticeTopic(
    id: 'TIU::Logika',
    category: 'TIU',
    subcategory: 'Logika',
    name: 'Logika',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU - INTELEGENSIA UMUM',
    badgeLabel: 'TIU',
    questionCount: 12,
  );

  static const PracticeQuestion question = PracticeQuestion(
    id: 'q1',
    sessionQuestionId: 'sq1',
    topicId: 'TIU::Logika',
    topicName: 'Logika',
    prompt: 'Find the odd one out: 2, 3, 5, 9, 11',
    hint: 'Only one number is not prime.',
    options: <PracticeOption>[
      PracticeOption(id: '0', label: '3', index: 0),
      PracticeOption(id: '1', label: '5', index: 1),
      PracticeOption(id: '2', label: '9', index: 2),
      PracticeOption(id: '3', label: '11', index: 3),
    ],
    questionOrder: 1,
    timeLimitSeconds: 60,
  );

  @override
  Future<PracticeDashboard> fetchDashboard() async {
    return const PracticeDashboard(
      topics: <PracticeTopic>[topic],
      overallProgressPercent: 28,
      recentActivities: <PracticeRecentActivity>[],
    );
  }

  @override
  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  }) async {
    return const PracticeSession(
      id: 'session-1',
      category: 'TIU',
      subcategory: 'Logika',
      totalQuestions: 1,
      questions: <PracticeQuestion>[question],
    );
  }

  @override
  Future<PracticeAnswerResult> submitAnswer({
    required String sessionId,
    required String sessionQuestionId,
    required int selectedOptionIndex,
    required int responseTimeMs,
    required bool usedHint,
  }) async {
    return const PracticeAnswerResult(
      isCorrect: true,
      correctOptionIndex: 2,
      explanation: 'Nine is not a prime number.',
      scoreGained: 10,
      progress: PracticeSessionSummary(
        totalQuestions: 1,
        answeredCount: 1,
        correctCount: 1,
        accuracy: 100,
        totalScore: 10,
      ),
    );
  }

  @override
  Future<PracticeSessionSummary> finishSession({
    required String sessionId,
  }) async {
    return const PracticeSessionSummary(
      totalQuestions: 1,
      answeredCount: 1,
      correctCount: 1,
      accuracy: 100,
      totalScore: 10,
    );
  }
}

void main() {
  testWidgets('renders practice dashboard from repository data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          practiceRepositoryProvider.overrideWithValue(
            const _SuccessPracticeRepository(),
          ),
        ],
        child: const MaterialApp(home: PracticePage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LATIHAN'), findsOneWidget);
    expect(find.text('Progress CPNS'), findsOneWidget);
    expect(find.text('Latihan Interview AI'), findsOneWidget);
    expect(find.text('TIU - INTELEGENSIA UMUM'), findsOneWidget);
    expect(find.text('TANTANGAN HARIAN'), findsNothing);
  });

  testWidgets('renders server session and unlocks its hint', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        practiceRepositoryProvider.overrideWithValue(
          const _SuccessPracticeRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(practiceControllerProvider.notifier).reload();
    await container
        .read(practiceControllerProvider.notifier)
        .startSession(_SuccessPracticeRepository.topic.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PracticeQuizPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Lihat petunjuk'), findsOneWidget);
    expect(find.text('KONFIRMASI'), findsOneWidget);
    await tester.tap(find.text('Lihat petunjuk'));
    await tester.pump();

    expect(find.text('PETUNJUK'), findsOneWidget);
    expect(find.text('Only one number is not prime.'), findsOneWidget);
  });

  testWidgets('opens the recommended practice after a battle', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.practice,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.practice,
          builder: (context, state) =>
              const PracticePage(focusCategory: 'logika'),
        ),
        GoRoute(
          path: AppRoutes.practiceQuiz,
          builder: (context, state) => const PracticeQuizPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          practiceRepositoryProvider.overrideWithValue(
            const _SuccessPracticeRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PracticeQuizPage), findsOneWidget);
    expect(find.text('Find the odd one out: 2, 3, 5, 9, 11'), findsOneWidget);
  });
}
