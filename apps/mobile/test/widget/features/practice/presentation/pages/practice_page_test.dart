import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_history_batch.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_history_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class _SuccessPracticeRepository implements PracticeRepository {
  const _SuccessPracticeRepository();

  static const PracticeTopic topic = PracticeTopic(
    id: 'tiu::kemampuan_logis',
    category: 'tiu',
    subcategory: 'kemampuan_logis',
    name: 'Kemampuan Logis',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU - INTELEGENSIA UMUM',
    badgeLabel: 'TIU',
    questionCount: 12,
  );

  static const PracticeTopic verbalTopic = PracticeTopic(
    id: 'tiu::kemampuan_verbal',
    category: 'tiu',
    subcategory: 'kemampuan_verbal',
    name: 'Kemampuan Verbal',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU - INTELEGENSIA UMUM',
    questionCount: 8,
  );

  static const PracticeTopic numerikTopic = PracticeTopic(
    id: 'tiu::kemampuan_numerik',
    category: 'tiu',
    subcategory: 'kemampuan_numerik',
    name: 'Kemampuan Numerik',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU - INTELEGENSIA UMUM',
    questionCount: 10,
  );

  static const PracticeTopic figuralTopic = PracticeTopic(
    id: 'tiu::kemampuan_figural',
    category: 'tiu',
    subcategory: 'kemampuan_figural',
    name: 'Kemampuan Figural',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'TIU',
    questionCount: 9,
  );

  static const PracticeTopic staleTopic = PracticeTopic(
    id: 'VERBAL::Silogisme',
    category: 'VERBAL',
    subcategory: 'Silogisme',
    name: 'Silogisme',
    description: 'Sesi latihan dengan 5 soal.',
    groupTitle: 'VERBAL',
    questionCount: 5,
  );

  static const PracticeQuestion question = PracticeQuestion(
    id: 'q1',
    sessionQuestionId: 'sq1',
    topicId: 'tiu::kemampuan_logis',
    topicName: 'Kemampuan Logis',
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
      topics: <PracticeTopic>[
        PracticeTopic(
          id: 'twk::pancasila_ideologi',
          category: 'twk',
          subcategory: 'pancasila_ideologi',
          name: 'Pancasila & Ideologi',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TWK',
        ),
        PracticeTopic(
          id: 'twk::konstitusi_negara',
          category: 'twk',
          subcategory: 'konstitusi_negara',
          name: 'Konstitusi & Negara',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TWK',
        ),
        PracticeTopic(
          id: 'twk::sejarah_kebangsaan',
          category: 'twk',
          subcategory: 'sejarah_kebangsaan',
          name: 'Sejarah & Kebangsaan',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TWK',
        ),
        PracticeTopic(
          id: 'twk::bhinneka_tunggal_ika',
          category: 'twk',
          subcategory: 'bhinneka_tunggal_ika',
          name: 'Bhinneka Tunggal Ika',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TWK',
        ),
        topic,
        verbalTopic,
        numerikTopic,
        figuralTopic,
        PracticeTopic(
          id: 'tkp::pelayanan_integritas',
          category: 'tkp',
          subcategory: 'pelayanan_integritas',
          name: 'Pelayanan & Integritas',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKP',
        ),
        PracticeTopic(
          id: 'tkp::kerja_sama_komunikasi',
          category: 'tkp',
          subcategory: 'kerja_sama_komunikasi',
          name: 'Kerja Sama & Komunikasi',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKP',
        ),
        PracticeTopic(
          id: 'tkp::adaptasi_pengembangan_diri',
          category: 'tkp',
          subcategory: 'adaptasi_pengembangan_diri',
          name: 'Adaptasi & Pengembangan Diri',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKP',
        ),
        PracticeTopic(
          id: 'tkp::pengambilan_keputusan_kinerja',
          category: 'tkp',
          subcategory: 'pengambilan_keputusan_kinerja',
          name: 'Pengambilan Keputusan & Kinerja',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKP',
        ),
        staleTopic,
      ],
      overallProgressPercent: 28,
      recentActivities: <PracticeRecentActivity>[
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Riwayat 1',
          subtitle: '5 dari 5 soal',
          scoreLabel: '100%',
        ),
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Riwayat 2',
          subtitle: '5 dari 5 soal',
          scoreLabel: '80%',
        ),
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Riwayat 3',
          subtitle: '5 dari 5 soal',
          scoreLabel: '60%',
        ),
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Riwayat 4',
          subtitle: '5 dari 5 soal',
          scoreLabel: '40%',
        ),
        PracticeRecentActivity(
          type: PracticeRecentActivityType.quiz,
          title: 'Riwayat 5',
          subtitle: '5 dari 5 soal',
          scoreLabel: '20%',
        ),
      ],
    );
  }

  @override
  Future<PracticeHistoryBatch> fetchHistory({
    required int limit,
    required int offset,
  }) async {
    final List<PracticeRecentActivity> allItems =
        List<PracticeRecentActivity>.generate(
          21,
          (int index) => PracticeRecentActivity(
            type: PracticeRecentActivityType.quiz,
            title: 'Riwayat ${index + 1}',
            subtitle: '5 dari 5 soal',
            scoreLabel: '80%',
          ),
        );
    final int end = (offset + limit).clamp(0, allItems.length);
    return PracticeHistoryBatch(
      items: offset >= allItems.length
          ? const <PracticeRecentActivity>[]
          : allItems.sublist(offset, end),
      limit: limit,
      offset: offset,
      total: allItems.length,
    );
  }

  @override
  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  }) async {
    return const PracticeSession(
      id: 'session-1',
      category: 'tiu',
      subcategory: 'kemampuan_logis',
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

class _RecordingPlayerProgressRepository extends PlayerProgressRepository {
  int fetchCount = 0;

  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async {
    fetchCount += 1;
    return const PlayerProgressSnapshot(
      playerId: 'user-1',
      displayName: 'Raka',
      totalPoints: 50,
      wins: 0,
      losses: 0,
      draws: 0,
      dailyMissions: <Map<String, Object?>>[
        <String, Object?>{
          'key': 'daily_practice',
          'title': 'Daily Question',
          'rewardRankPoints': 50,
          'completed': true,
        },
      ],
    );
  }
}

class _BumnPracticeRepository extends _SuccessPracticeRepository {
  const _BumnPracticeRepository();

  @override
  Future<PracticeDashboard> fetchDashboard() async {
    return const PracticeDashboard(
      topics: <PracticeTopic>[
        PracticeTopic(
          id: 'tkd::kemampuan_verbal',
          category: 'tkd',
          subcategory: 'kemampuan_verbal',
          name: 'Kemampuan Verbal',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKD',
        ),
        PracticeTopic(
          id: 'tkd::kemampuan_numerik',
          category: 'tkd',
          subcategory: 'kemampuan_numerik',
          name: 'Kemampuan Numerik',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKD',
        ),
        PracticeTopic(
          id: 'tkd::kemampuan_logis',
          category: 'tkd',
          subcategory: 'kemampuan_logis',
          name: 'Kemampuan Logis',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKD',
        ),
        PracticeTopic(
          id: 'tkd::kemampuan_figural',
          category: 'tkd',
          subcategory: 'kemampuan_figural',
          name: 'Kemampuan Figural',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'TKD',
        ),
        PracticeTopic(
          id: 'akhlak::amanah',
          category: 'akhlak',
          subcategory: 'amanah',
          name: 'Amanah',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'AKHLAK',
        ),
        PracticeTopic(
          id: 'akhlak::kompeten',
          category: 'akhlak',
          subcategory: 'kompeten',
          name: 'Kompeten',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'AKHLAK',
        ),
        PracticeTopic(
          id: 'akhlak::harmonis',
          category: 'akhlak',
          subcategory: 'harmonis',
          name: 'Harmonis',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'AKHLAK',
        ),
        PracticeTopic(
          id: 'akhlak::loyal',
          category: 'akhlak',
          subcategory: 'loyal',
          name: 'Loyal',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'AKHLAK',
        ),
        PracticeTopic(
          id: 'wawasan_kebangsaan::pancasila',
          category: 'wawasan_kebangsaan',
          subcategory: 'pancasila',
          name: 'Pancasila',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'WAWASAN KEBANGSAAN',
        ),
        PracticeTopic(
          id: 'wawasan_kebangsaan::uud_1945',
          category: 'wawasan_kebangsaan',
          subcategory: 'uud_1945',
          name: 'UUD 1945',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'WAWASAN KEBANGSAAN',
        ),
        PracticeTopic(
          id: 'wawasan_kebangsaan::nkri',
          category: 'wawasan_kebangsaan',
          subcategory: 'nkri',
          name: 'NKRI',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'WAWASAN KEBANGSAAN',
        ),
        PracticeTopic(
          id: 'wawasan_kebangsaan::bhinneka_tunggal_ika',
          category: 'wawasan_kebangsaan',
          subcategory: 'bhinneka_tunggal_ika',
          name: 'Bhinneka Tunggal Ika',
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'WAWASAN KEBANGSAAN',
        ),
      ],
      overallProgressPercent: 12,
      recentActivities: <PracticeRecentActivity>[],
    );
  }
}

class _NoopProfileSettingsStorage implements ProfileSettingsStorage {
  const _NoopProfileSettingsStorage();

  @override
  Future<ProfileSettings?> load() async => null;

  @override
  Future<void> save(ProfileSettings settings) async {}
}

class _TwoQuestionPracticeRepository extends _SuccessPracticeRepository {
  const _TwoQuestionPracticeRepository();

  static const PracticeQuestion secondQuestion = PracticeQuestion(
    id: 'q2',
    sessionQuestionId: 'sq2',
    topicId: 'tiu::kemampuan_logis',
    topicName: 'Kemampuan Logis',
    prompt: 'What comes next: 2, 4, 8, 16?',
    hint: 'Each number doubles.',
    options: <PracticeOption>[
      PracticeOption(id: '0', label: '18', index: 0),
      PracticeOption(id: '1', label: '24', index: 1),
      PracticeOption(id: '2', label: '30', index: 2),
      PracticeOption(id: '3', label: '32', index: 3),
    ],
    questionOrder: 2,
    timeLimitSeconds: 60,
  );

  @override
  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  }) async {
    return const PracticeSession(
      id: 'session-2',
      category: 'tiu',
      subcategory: 'kemampuan_logis',
      totalQuestions: 2,
      questions: <PracticeQuestion>[
        _SuccessPracticeRepository.question,
        secondQuestion,
      ],
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
        totalQuestions: 2,
        answeredCount: 1,
        correctCount: 1,
        accuracy: 100,
        totalScore: 10,
      ),
    );
  }
}

void main() {
  testWidgets('renders practice dashboard from repository data', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
    expect(
      find.byKey(const ValueKey<String>('practice-target-badge')),
      findsOneWidget,
    );
    expect(find.text('Progress latihan'), findsOneWidget);
    expect(find.text('28%'), findsOneWidget);
    expect(find.text('Simulasi Wawancara AI'), findsOneWidget);
    expect(find.text('LATIHAN SOAL CPNS'), findsOneWidget);
    expect(find.text('4 subkategori • 5 soal per sesi'), findsNWidgets(3));
    expect(find.text('TWK'), findsOneWidget);
    expect(find.text('TIU'), findsOneWidget);
    expect(find.text('TKP'), findsOneWidget);
    expect(find.text('Pancasila & Ideologi'), findsOneWidget);
    expect(find.text('Kemampuan Verbal'), findsOneWidget);
    expect(find.text('Kemampuan Logis'), findsOneWidget);
    expect(find.text('Pelayanan & Integritas'), findsOneWidget);
    expect(find.text('Pengambilan Keputusan & Kinerja'), findsOneWidget);
    expect(find.text('Silogisme'), findsNothing);
    expect(find.text('12 tersedia'), findsNothing);
    expect(find.text('Mulai'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    expect(find.text('Sesi latihan dengan 5 soal.'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('practice-topic-tiu::kemampuan_verbal'),
      ),
      findsOneWidget,
    );
    final DecoratedBox twkSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>(
          'practice-topic-surface-twk::pancasila_ideologi',
        ),
      ),
    );
    expect(
      (twkSurface.decoration as BoxDecoration).color,
      const Color(0xFFFDE9D6),
    );
    final DecoratedBox tiuSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>('practice-topic-surface-tiu::kemampuan_verbal'),
      ),
    );
    expect(
      (tiuSurface.decoration as BoxDecoration).color,
      const Color(0xFFE0F6FB),
    );
    final DecoratedBox tkpSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>(
          'practice-topic-surface-tkp::pelayanan_integritas',
        ),
      ),
    );
    expect(
      (tkpSurface.decoration as BoxDecoration).color,
      const Color(0xFFEBF8DA),
    );
    expect(find.text('TANTANGAN HARIAN'), findsNothing);
    expect(find.text('Lihat semua'), findsOneWidget);
    expect(find.text('Riwayat 1'), findsOneWidget);
    expect(find.text('Riwayat 2'), findsOneWidget);
    expect(find.text('Riwayat 3'), findsOneWidget);
    expect(find.text('Riwayat 4'), findsNothing);
    expect(find.text('Riwayat 5'), findsNothing);

    final Container progressSurface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('practice-progress-surface')),
    );
    final BoxDecoration progressDecoration =
        progressSurface.decoration! as BoxDecoration;
    expect(progressDecoration.color, const Color(0xFF0D49B5));
    expect(
      progressDecoration.borderRadius,
      const BorderRadius.vertical(bottom: Radius.circular(26)),
    );
    final DecoratedBox progressBase = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('practice-progress-clay-base')),
    );
    expect(
      (progressBase.decoration as BoxDecoration).color,
      const Color(0xFF06378F),
    );
    final Container interviewSurface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('practice-interview-surface')),
    );
    expect((interviewSurface.decoration! as BoxDecoration).color, Colors.white);
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
    DecoratedBox confirmSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('practice-action-surface-confirm')),
    );
    expect(
      (confirmSurface.decoration as BoxDecoration).color,
      const Color(0xFFEAE6DE),
    );
    await tester.tap(find.text('9'));
    await tester.pump();
    confirmSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('practice-action-surface-confirm')),
    );
    expect(
      (confirmSurface.decoration as BoxDecoration).color,
      AppColors.fireGold,
    );
    await tester.tap(find.text('Lihat petunjuk'));
    await tester.pump();

    expect(find.text('PETUNJUK'), findsOneWidget);
    expect(find.text('Only one number is not prime.'), findsOneWidget);
  });

  testWidgets('groups the canonical BUMN taxonomy by category', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        practiceRepositoryProvider.overrideWithValue(
          const _BumnPracticeRepository(),
        ),
        profileSettingsStorageProvider.overrideWithValue(
          const _NoopProfileSettingsStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(profileSettingsProvider.notifier)
        .setTarget(ProfileTarget.bumn);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PracticePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BUMN'), findsOneWidget);
    expect(find.text('LATIHAN SOAL BUMN'), findsOneWidget);
    expect(find.text('4 subkategori • 5 soal per sesi'), findsNWidgets(3));
    expect(find.text('TKD'), findsOneWidget);
    expect(find.text('AKHLAK'), findsOneWidget);
    expect(find.text('WAWASAN KEBANGSAAN'), findsOneWidget);
    expect(find.text('Kemampuan Verbal'), findsOneWidget);
    expect(find.text('Kemampuan Figural'), findsOneWidget);
    expect(find.text('Amanah'), findsOneWidget);
    expect(find.text('Loyal'), findsOneWidget);
    expect(find.text('Pancasila'), findsOneWidget);
    expect(find.text('Bhinneka Tunggal Ika'), findsOneWidget);
    expect(find.text('Kepribadian'), findsNothing);
    expect(find.text('Adaptif'), findsNothing);
    expect(find.text('TERAKHIR DIKERJAKAN'), findsOneWidget);
    expect(find.text('Belum ada latihan yang dikerjakan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('practice-history-empty')),
      findsOneWidget,
    );
    expect(find.text('Lihat semua'), findsNothing);
    final DecoratedBox tkdSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>('practice-topic-surface-tkd::kemampuan_verbal'),
      ),
    );
    expect(
      (tkdSurface.decoration as BoxDecoration).color,
      const Color(0xFFE0F6FB),
    );
    final DecoratedBox akhlakSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>('practice-topic-surface-akhlak::amanah'),
      ),
    );
    expect(
      (akhlakSurface.decoration as BoxDecoration).color,
      const Color(0xFFEBF8DA),
    );
    final DecoratedBox wawasanSurface = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>(
          'practice-topic-surface-wawasan_kebangsaan::pancasila',
        ),
      ),
    );
    expect(
      (wawasanSurface.decoration as BoxDecoration).color,
      const Color(0xFFFDE9D6),
    );
  });

  testWidgets('loads and paginates the full practice history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          practiceRepositoryProvider.overrideWithValue(
            const _SuccessPracticeRepository(),
          ),
        ],
        child: const MaterialApp(home: PracticeHistoryPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RIWAYAT LATIHAN'), findsOneWidget);
    expect(find.text('Riwayat 21'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Muat lebih banyak'),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Riwayat 21'), findsOneWidget);
    expect(find.text('Muat lebih banyak'), findsNothing);
  });

  testWidgets('refreshes player progress after completing a session', (
    WidgetTester tester,
  ) async {
    final _RecordingPlayerProgressRepository progressRepository =
        _RecordingPlayerProgressRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        practiceRepositoryProvider.overrideWithValue(
          const _SuccessPracticeRepository(),
        ),
        playerProgressRepositoryProvider.overrideWithValue(progressRepository),
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
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('KONFIRMASI'));
    await tester.pumpAndSettle();

    expect(progressRepository.fetchCount, 1);
    expect(find.text('SESI SELESAI'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('practice-action-complete')),
      findsOneWidget,
    );
    final DecoratedBox completeSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('practice-action-surface-complete')),
    );
    expect(
      (completeSurface.decoration as BoxDecoration).color,
      AppColors.growthLime,
    );
  });

  testWidgets('uses blue clay styling to continue a session', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        practiceRepositoryProvider.overrideWithValue(
          const _TwoQuestionPracticeRepository(),
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
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('KONFIRMASI'));
    await tester.pumpAndSettle();

    expect(find.text('LANJUT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('practice-action-next')),
      findsOneWidget,
    );
    final DecoratedBox nextSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('practice-action-surface-next')),
    );
    expect(
      (nextSurface.decoration as BoxDecoration).color,
      const Color(0xFF0066DE),
    );
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
