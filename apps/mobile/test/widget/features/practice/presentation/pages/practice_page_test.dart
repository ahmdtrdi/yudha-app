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
  testWidgets('renders loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          practiceRepositoryProvider.overrideWithValue(
            const _PendingPracticeRepository(),
          ),
        ],
        child: const MaterialApp(home: PracticePage()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders practice content in success state', (
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

    await tester.pumpAndSettle();

    expect(find.text('Question of the Day'), findsOneWidget);
    expect(find.text('Choose Topic'), findsOneWidget);
    expect(find.text('Submit Answer'), findsOneWidget);
    expect(find.text('Hint is locked. Choose unlock method:'), findsOneWidget);
  });

  testWidgets('supports hint unlock stub flow', (WidgetTester tester) async {
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

    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch Ad'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ad reward pending. Complete ad to unlock this hint.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Unlock Hint'));
    await tester.pumpAndSettle();

    expect(find.text('Only one number is not prime.'), findsOneWidget);
  });
}

