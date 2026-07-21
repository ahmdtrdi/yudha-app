import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class _SuccessPracticeRepository implements PracticeRepository {
  const _SuccessPracticeRepository();

  @override
  Future<PracticeDashboard> fetchDashboard({
    required ProfileTarget target,
  }) async {
    return const PracticeDashboard(
      topics: <PracticeTopic>[
        PracticeTopic(
          id: 'logic',
          name: 'Logic',
          description: 'Pattern recognition.',
          groupTitle: 'TWK - WAWASAN KEBANGSAAN',
          badgeLabel: 'TWK',
          questionCount: 12,
        ),
      ],
      questionOfDay: PracticeQuestion(
        id: 'qod',
        topicId: 'logic',
        topicName: 'Logic',
        prompt: 'Question of the Day: Next in 2, 4, 8, ...?',
        hint: 'Multiply by 2 each step.',
        isQuestionOfDay: true,
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '12', isCorrect: false),
          PracticeOption(id: 'b', label: '16', isCorrect: true),
        ],
      ),
      overallProgressPercent: 28,
      recentActivities: <PracticeRecentActivity>[
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'TWK - Pancasila',
          subtitle: '15 soal - 2 hari lalu',
          scoreLabel: '80%',
        ),
      ],
    );
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({
    required String topicId,
  }) async {
    return const <PracticeQuestion>[
      PracticeQuestion(
        id: 'q1',
        topicId: 'logic',
        topicName: 'Logic',
        prompt: 'Find the odd one out: 2, 3, 5, 9, 11',
        hint: 'Only one number is not prime.',
        options: <PracticeOption>[
          PracticeOption(id: 'a', label: '3', isCorrect: false),
          PracticeOption(id: 'b', label: '5', isCorrect: false),
          PracticeOption(id: 'c', label: '9', isCorrect: true),
          PracticeOption(id: 'd', label: '11', isCorrect: false),
        ],
      ),
    ];
  }
}

void main() {
  testWidgets('renders practice dashboard layout successfully', (
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
    expect(find.text('CPNS'), findsOneWidget);
    expect(find.text('Progress CPNS'), findsOneWidget);
    expect(find.text('Latihan Interview AI'), findsOneWidget);
    expect(find.text('TWK - WAWASAN KEBANGSAAN'), findsOneWidget);
  });

  testWidgets('renders practice quiz page and transforms hint', (
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

    final controller = container.read(practiceControllerProvider.notifier);
    await controller.load();
    controller.startQuestionOfDay();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PracticeQuizPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lihat petunjuk'), findsOneWidget);
    expect(find.text('KONFIRMASI'), findsOneWidget);
    expect(find.text('-5 poin'), findsOneWidget);

    await tester.tap(find.text('Lihat petunjuk'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PETUNJUK'), findsOneWidget);
    expect(find.text('Multiply by 2 each step.'), findsOneWidget);
    expect(find.text('Lihat petunjuk'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
