import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/live_interview_speech_client.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_page.dart';

void main() {
  testWidgets('renders the active voice room as a full-screen gradient stage', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authAccessTokenProvider.overrideWithValue(null),
          interviewRepositoryProvider.overrideWithValue(
            _InterviewPageRepository(),
          ),
          liveInterviewAudioCaptureFactoryProvider.overrideWithValue(
            () => _FakeLiveAudioCapture(),
          ),
          liveInterviewAudioPlayerFactoryProvider.overrideWithValue(
            () => _FakeLiveAudioPlayer(),
          ),
          liveInterviewSpeechClientFactoryProvider.overrideWithValue(
            (_) => _FakeLiveSpeechClient(),
          ),
        ],
        child: const MaterialApp(home: InterviewPage(config: _voiceConfig)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final DecoratedBox background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('interview-page-background')),
    );
    final BoxDecoration backgroundDecoration =
        background.decoration as BoxDecoration;
    final LinearGradient gradient =
        backgroundDecoration.gradient! as LinearGradient;
    expect(gradient.colors, const <Color>[
      Color(0xFF0D49B5),
      Color(0xFF0875AE),
      Color(0xFF06AAA9),
    ]);
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);

    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF0D49B5));
    expect(
      find.byKey(const ValueKey<String>('interview-voice-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-voice-mode-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-question-surface')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('interview-voice-orb'))),
      const Size.square(180),
    );

    expect(
      find.byKey(const ValueKey<String>('interview-floating-composer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-answer-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('live-interview-mute')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('live-interview-push-to-talk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('live-interview-end-call')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('live-interview-text-fallback')),
      findsOneWidget,
    );
    expect(find.text(_openingQuestion), findsOneWidget);
    expect(find.text('Tekan dan tahan untuk menjawab'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final TestGesture pushToTalk = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('live-interview-push-to-talk')),
      ),
    );
    await tester.pump();
    expect(find.text('Lepaskan untuk mengirim'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('live-interview-recording-duration')),
      findsOneWidget,
    );
    await pushToTalk.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(
      find.byKey(const ValueKey<String>('live-interview-end-call')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tinggalkan interview?'), findsOneWidget);
    expect(find.textContaining('Sesi tetap tersimpan'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('interview-confirmation-cancel')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey<String>('live-interview-text-fallback')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('interview-voice-stage')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-floating-composer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-answer-field')),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(const Size(390, 680));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('interview-floating-composer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('interview-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.text('Tinggalkan interview?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('interview-confirmation-cancel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-confirmation-confirm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('interview-confirmation-cancel')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('interview-confirmation-dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-floating-composer')),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders the completed interview result and keeps actions wired',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.interview,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.interview,
            builder: (_, _) => const InterviewPage(config: _completedConfig),
          ),
          GoRoute(
            path: AppRoutes.interviewSetup,
            builder: (_, _) => const Scaffold(body: Text('Setup destination')),
          ),
          GoRoute(
            path: AppRoutes.practice,
            builder: (_, _) =>
                const Scaffold(body: Text('Practice destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authAccessTokenProvider.overrideWithValue(null),
            interviewRepositoryProvider.overrideWithValue(
              const _CompletedInterviewRepository(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('interview-result-view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('interview-result-hero')),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey<String>('interview-result-score')),
        ),
        const Size.square(126),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('interview-result-score')),
          matching: find.text('82'),
        ),
        findsOneWidget,
      );
      expect(find.text('Siap'), findsOneWidget);
      final Container statusBadge = tester.widget<Container>(
        find.byKey(const ValueKey<String>('interview-result-status')),
      );
      expect(
        (statusBadge.decoration! as BoxDecoration).color,
        const Color(0xFFDDF7F3),
      );
      expect(find.text('3 jawaban telah dinilai'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('result-dimensions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('result-strengths')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('result-improvements')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('result-suggested-rewrite')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('result-start-new')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('result-start-new')));
      await tester.pumpAndSettle();
      expect(find.text('Setup destination'), findsOneWidget);

      router.go(AppRoutes.interview);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('result-back-practice')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('result-back-practice')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Practice destination'), findsOneWidget);
    },
  );

  testWidgets('opens a scrollable session detail and returns to history', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authAccessTokenProvider.overrideWithValue(null),
          interviewRepositoryProvider.overrideWithValue(
            const _CompletedInterviewRepository(),
          ),
        ],
        child: const MaterialApp(home: InterviewPage(config: _completedConfig)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Riwayat chat'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Interview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('interview-session-session-completed')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('interview-session-session-completed')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail sesi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('session-detail-back')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('interview-session-scrollbar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('session-detail-back')));
    await tester.pumpAndSettle();
    expect(find.text('Detail sesi'), findsNothing);
    expect(find.text('Riwayat Interview'), findsOneWidget);
  });
}

class _FakeLiveAudioCapture implements LiveInterviewAudioCapture {
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start() async => Stream<Uint8List>.empty();

  @override
  Future<void> stop() async {}
}

class _FakeLiveAudioPlayer implements LiveInterviewAudioPlayer {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> playBytes(
    Uint8List bytes, {
    required String fileExtension,
  }) async {}

  @override
  Future<void> playUrl(String url, {String? accessToken}) async {}

  @override
  Future<void> stop() async {}
}

class _FakeLiveSpeechClient extends LiveInterviewSpeechClient {
  _FakeLiveSpeechClient() : super(baseUrl: 'http://test', accessToken: 'test');

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(String sessionId) async {}

  @override
  void cancel({String? answerId}) {}

  @override
  Future<void> disconnect() async {}
}

const InterviewLaunchConfig _voiceConfig = InterviewLaunchConfig(
  companyId: 'adhi-karya',
  companyName: 'PT Adhi Karya (Persero) Tbk.',
  targetRole: 'Management Trainee',
  responseStyle: 'voice',
);

const InterviewLaunchConfig _completedConfig = InterviewLaunchConfig(
  companyId: 'adhi-karya',
  companyName: 'PT Adhi Karya (Persero) Tbk.',
  targetRole: 'Management Trainee',
  mode: 'coaching',
  responseStyle: 'text',
  resumeSessionId: 'session-completed',
);

const String _openingQuestion =
    'Halo! Ceritakan pengalaman Anda memimpin sebuah tim.';

class _InterviewPageRepository implements InterviewRepository {
  @override
  Future<InterviewStartResult> startSession(
    InterviewLaunchConfig config,
  ) async {
    return InterviewStartResult(
      sessionId: 'session-1',
      status: 'active',
      openingQuestion: InterviewMessage(
        id: 'turn-1',
        author: InterviewMessageAuthor.interviewer,
        text: _openingQuestion,
        createdAt: DateTime(2026, 8, 20),
      ),
    );
  }

  @override
  String getQuestionAudioUrl({
    required String sessionId,
    required String turnId,
  }) {
    return 'https://example.invalid/$sessionId/$turnId.mp3';
  }

  @override
  Future<List<InterviewSessionSummaryRecord>> listSessions() async {
    return const <InterviewSessionSummaryRecord>[];
  }

  @override
  Future<InterviewSessionDetailRecord> getSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<InterviewTurnResult> submitAnswer({
    required String sessionId,
    required String answer,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<InterviewFinalSummary> completeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<String> transcribeAnswerAudio({
    required String sessionId,
    required List<int> audioBytes,
    required String filename,
  }) {
    throw UnimplementedError();
  }
}

class _CompletedInterviewRepository implements InterviewRepository {
  const _CompletedInterviewRepository();

  @override
  Future<InterviewSessionDetailRecord> getSession(String sessionId) async {
    return InterviewSessionDetailRecord(
      sessionId: sessionId,
      status: 'completed',
      companyId: 'adhi-karya',
      targetRole: 'Management Trainee',
      mode: 'coaching',
      responseStyle: 'text',
      messages: <InterviewMessage>[
        InterviewMessage(
          id: 'answer-3',
          author: InterviewMessageAuthor.candidate,
          text: 'Saya memimpin tim dan meningkatkan hasil proyek.',
          createdAt: DateTime(2026, 8, 25),
          evaluation: const InterviewEvaluation(
            overallScore: 82,
            strengths: <String>['Jawaban jelas dan relevan.'],
            improvements: <String>['Tambahkan dampak yang terukur.'],
            suggestedRewrite:
                'Saya memimpin lima anggota tim dan meningkatkan hasil proyek sebesar 20 persen.',
          ),
        ),
      ],
      finalSummary: const InterviewFinalSummary(
        overallScore: 82,
        answerCount: 3,
        dimensions: InterviewDimensions(
          relevance: 84,
          clarity: 82,
          structure: 80,
          confidence: 78,
          impact: 76,
          authenticity: 88,
        ),
        strengths: <String>[
          'Jawaban relevan dengan posisi yang dituju.',
          'Penyampaian terdengar percaya diri.',
        ],
        improvements: <String>['Tambahkan hasil yang lebih terukur.'],
      ),
    );
  }

  @override
  Future<List<InterviewSessionSummaryRecord>> listSessions() async {
    final DateTime timestamp = DateTime(2026, 8, 25, 10, 30);
    return <InterviewSessionSummaryRecord>[
      InterviewSessionSummaryRecord(
        sessionId: 'session-completed',
        status: 'completed',
        companyId: 'adhi-karya',
        targetRole: 'Management Trainee',
        mode: 'coaching',
        language: 'id',
        responseStyle: 'text',
        createdAt: timestamp,
        updatedAt: timestamp,
        finalSummary: const InterviewFinalSummary(
          overallScore: 82,
          answerCount: 3,
          dimensions: InterviewDimensions(),
          strengths: <String>[],
          improvements: <String>[],
        ),
      ),
    ];
  }

  @override
  Future<InterviewStartResult> startSession(InterviewLaunchConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<InterviewTurnResult> submitAnswer({
    required String sessionId,
    required String answer,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<InterviewFinalSummary> completeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  String getQuestionAudioUrl({
    required String sessionId,
    required String turnId,
  }) {
    return '';
  }

  @override
  Future<String> transcribeAnswerAudio({
    required String sessionId,
    required List<int> audioBytes,
    required String filename,
  }) {
    throw UnimplementedError();
  }
}
