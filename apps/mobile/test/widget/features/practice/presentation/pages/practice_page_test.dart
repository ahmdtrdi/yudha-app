import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';

class _PendingPracticeRepository implements PracticeRepository {
  const _PendingPracticeRepository();

  @override
  Future<PracticeQuestion> fetchQuestionOfDay() {
    return Completer<PracticeQuestion>().future;
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({required String topicId}) {
    return Completer<List<PracticeQuestion>>().future;
  }

  @override
  Future<List<PracticeTopic>> fetchTopics() {
    return Completer<List<PracticeTopic>>().future;
  }
}

class _SuccessPracticeRepository implements PracticeRepository {
  const _SuccessPracticeRepository();

  @override
  Future<PracticeQuestion> fetchQuestionOfDay() async {
    return const PracticeQuestion(
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
    );
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({required String topicId}) async {
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

  @override
  Future<List<PracticeTopic>> fetchTopics() async {
    return const <PracticeTopic>[
      PracticeTopic(
        id: 'logic',
        name: 'Logic',
        description: 'Pattern recognition.',
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

    // Let the mock fetch complete
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LATIHAN'), findsOneWidget);
    expect(find.text('CPNS'), findsOneWidget); // Default target badge
    expect(find.text('Progress CPNS'), findsOneWidget);
    expect(find.text('TWK — WAWASAN KEBANGSAAN'), findsOneWidget);
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

    // Give the fake controller time to load() its initial data
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Start the mock challenge so PracticeQuizPage doesn't render "No question active"
    container.read(practiceControllerProvider.notifier).startQuestionOfDay();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PracticeQuizPage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    // Verify initial quiz UI
    expect(find.text('Lihat petunjuk'), findsOneWidget);
    expect(find.text('KONFIRMASI'), findsOneWidget);
    expect(find.text('-5 poin'), findsOneWidget);

    // Tap hint to unlock
    await tester.tap(find.text('Lihat petunjuk'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify hint box morphed
    expect(find.text('PETUNJUK'), findsOneWidget);
    expect(find.text('Only one number is not prime.'), findsOneWidget);
    // Dashed button should disappear entirely
    expect(find.text('Lihat petunjuk'), findsNothing);
  });
}
