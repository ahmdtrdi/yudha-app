import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/practice/application/practice_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class _FakePracticeRepository implements PracticeRepository {
  int? lastResponseTimeMs;
  bool? lastUsedHint;
  int submitCount = 0;
  int dashboardFetchCount = 0;

  static const PracticeTopic topic = PracticeTopic(
    id: 'TIU::Numerik',
    category: 'TIU',
    subcategory: 'Numerik',
    name: 'Numerik',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU',
    questionCount: 10,
  );

  static const List<PracticeQuestion> questions = <PracticeQuestion>[
    PracticeQuestion(
      id: 'q1',
      sessionQuestionId: 'sq1',
      topicId: 'TIU::Numerik',
      topicName: 'Numerik',
      prompt: 'Dua tambah dua?',
      options: <PracticeOption>[
        PracticeOption(id: '0', label: '3', index: 0),
        PracticeOption(id: '1', label: '4', index: 1),
      ],
      hint: 'Hitung perlahan.',
      questionOrder: 1,
      timeLimitSeconds: 60,
    ),
    PracticeQuestion(
      id: 'q2',
      sessionQuestionId: 'sq2',
      topicId: 'TIU::Numerik',
      topicName: 'Numerik',
      prompt: 'Tiga tambah tiga?',
      options: <PracticeOption>[
        PracticeOption(id: '0', label: '5', index: 0),
        PracticeOption(id: '1', label: '6', index: 1),
      ],
      hint: 'Hitung sekali lagi.',
      questionOrder: 2,
      timeLimitSeconds: 60,
    ),
  ];

  @override
  Future<PracticeDashboard> fetchDashboard() async {
    dashboardFetchCount += 1;
    return const PracticeDashboard(
      topics: <PracticeTopic>[topic],
      overallProgressPercent: 50,
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
      subcategory: 'Numerik',
      totalQuestions: 2,
      questions: questions,
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
    lastResponseTimeMs = responseTimeMs;
    lastUsedHint = usedHint;
    submitCount += 1;
    final bool correct = selectedOptionIndex == 1;
    return PracticeAnswerResult(
      isCorrect: correct,
      correctOptionIndex: 1,
      explanation: 'Jawaban yang benar adalah pilihan kedua.',
      scoreGained: correct ? 10 : 0,
      progress: PracticeSessionSummary(
        totalQuestions: 2,
        answeredCount: submitCount,
        correctCount: submitCount,
        accuracy: 100,
        totalScore: submitCount * 10,
      ),
    );
  }

  @override
  Future<PracticeSessionSummary> finishSession({
    required String sessionId,
  }) async {
    return const PracticeSessionSummary(
      totalQuestions: 2,
      answeredCount: 2,
      correctCount: 2,
      accuracy: 100,
      totalScore: 20,
    );
  }
}

class _EmptyProfileSettingsStorage implements ProfileSettingsStorage {
  const _EmptyProfileSettingsStorage();

  @override
  Future<ProfileSettings?> load() async => null;

  @override
  Future<void> save(ProfileSettings settings) async {}
}

void main() {
  test('loads dashboard without creating a practice session', () async {
    final _FakePracticeRepository repository = _FakePracticeRepository();
    final PracticeController controller = PracticeController(
      repository: repository,
    );

    await controller.reload();

    expect(controller.state.status, PracticeViewStatus.ready);
    expect(controller.state.topics, <PracticeTopic>[
      _FakePracticeRepository.topic,
    ]);
    expect(controller.state.questions, isEmpty);
    expect(controller.state.sessionId, isNull);
  });

  test('reloads dashboard when the profile target changes', () async {
    final _FakePracticeRepository repository = _FakePracticeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        practiceRepositoryProvider.overrideWithValue(repository),
        profileSettingsStorageProvider.overrideWithValue(
          const _EmptyProfileSettingsStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      practiceControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final PracticeController initialController = container.read(
      practiceControllerProvider.notifier,
    );
    await initialController.reload();
    final int initialFetchCount = repository.dashboardFetchCount;

    container
        .read(profileSettingsProvider.notifier)
        .setTarget(ProfileTarget.cpns);
    await Future<void>.delayed(Duration.zero);

    final PracticeController refreshedController = container.read(
      practiceControllerProvider.notifier,
    );

    expect(refreshedController, isNot(same(initialController)));
    expect(repository.dashboardFetchCount, greaterThan(initialFetchCount));
  });

  test('starts locked session and submits response time to backend', () async {
    final _FakePracticeRepository repository = _FakePracticeRepository();
    DateTime now = DateTime(2026, 7, 21, 10);
    final PracticeController controller = PracticeController(
      repository: repository,
      now: () => now,
    );
    await controller.reload();

    final bool started = await controller.startSession(
      _FakePracticeRepository.topic.id,
    );
    now = now.add(const Duration(milliseconds: 2750));
    controller.unlockHint();
    controller.selectOption('1');
    final bool submitted = await controller.submitCurrentAnswer();

    expect(started, isTrue);
    expect(submitted, isTrue);
    expect(controller.state.sessionId, 'session-1');
    expect(controller.state.questions, hasLength(2));
    expect(repository.lastResponseTimeMs, 2750);
    expect(repository.lastUsedHint, isTrue);
    expect(controller.state.correctOptionIndex, 1);
    expect(controller.state.answerExplanation, isNotNull);
  });

  test('starts the practice topic that matches a battle category', () async {
    final _FakePracticeRepository repository = _FakePracticeRepository();
    final PracticeController controller = PracticeController(
      repository: repository,
    );
    await controller.reload();

    final bool started = await controller.startRecommendedSession('numerik');

    expect(started, isTrue);
    expect(controller.state.selectedTopicId, _FakePracticeRepository.topic.id);
    expect(controller.state.sessionId, 'session-1');
  });

  test('finishes the server session after the final answer', () async {
    final _FakePracticeRepository repository = _FakePracticeRepository();
    final PracticeController controller = PracticeController(
      repository: repository,
    );
    await controller.reload();
    await controller.startSession(_FakePracticeRepository.topic.id);

    controller.selectOption('1');
    await controller.submitCurrentAnswer();
    controller.nextQuestion();
    controller.selectOption('1');
    await controller.submitCurrentAnswer();

    expect(controller.state.status, PracticeViewStatus.completed);
    expect(controller.state.summary?.totalScore, 20);
    expect(controller.state.correctAnswers, 2);
  });
}
