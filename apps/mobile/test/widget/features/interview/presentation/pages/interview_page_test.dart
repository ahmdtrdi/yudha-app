import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
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

    final Finder composer = find.byKey(
      const ValueKey<String>('interview-floating-composer'),
    );
    final Container composerContainer = tester.widget<Container>(composer);
    final BoxDecoration composerDecoration =
        composerContainer.decoration! as BoxDecoration;
    expect(composerContainer.margin, const EdgeInsets.fromLTRB(20, 8, 20, 18));
    expect(composerContainer.padding, const EdgeInsets.fromLTRB(8, 4, 4, 4));
    expect(composerDecoration.color, Colors.white);
    expect(composerDecoration.borderRadius, BorderRadius.circular(30));
    final TextField answerField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('interview-answer-field')),
    );
    expect(answerField.minLines, 1);
    expect(answerField.maxLines, 1);
    expect(answerField.textInputAction, TextInputAction.send);
    expect(answerField.decoration?.hintMaxLines, 1);
    expect(answerField.decoration?.hintStyle?.fontSize, 11.5);
    expect(find.text('Siap mendengarkan'), findsOneWidget);
    expect(find.text(_openingQuestion), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 680));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('interview-floating-composer')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

const InterviewLaunchConfig _voiceConfig = InterviewLaunchConfig(
  companyId: 'adhi-karya',
  companyName: 'PT Adhi Karya (Persero) Tbk.',
  targetRole: 'Management Trainee',
  responseStyle: 'voice',
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
