import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/interview/application/interview_controller.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

void main() {
  test('starts session and submits answer', () async {
    final InterviewController controller = InterviewController(
      repository: _FakeInterviewRepository(),
      config: InterviewLaunchConfig.bumnDefault(),
    );

    await controller.start();

    expect(controller.state.status, InterviewViewStatus.active);
    expect(controller.state.sessionId, 'session-1');
    expect(controller.state.messages.single.text, 'Perkenalkan diri Anda.');

    await controller.submitAnswer('Saya siap belajar dan berkontribusi.');

    expect(controller.state.status, InterviewViewStatus.active);
    expect(controller.state.messages.length, 3);
    expect(
      controller.state.messages.last.text,
      'Mengapa memilih perusahaan ini?',
    );
    expect(controller.state.latestEvaluation?.overallScore, 82);
  });

  test('retry resumes session when sessionId is available', () async {
    final InterviewController controller = InterviewController(
      repository: _FakeInterviewRepository(),
      config: InterviewLaunchConfig.bumnDefault(),
    );

    await controller.start();
    expect(controller.state.sessionId, 'session-1');

    await controller.retry();
    expect(controller.state.status, InterviewViewStatus.completed);
  });

  test('transcription failure keeps the interview session usable', () async {
    final InterviewController controller = InterviewController(
      repository: _FakeInterviewRepository(shouldFailTranscription: true),
      config: InterviewLaunchConfig.bumnDefault(),
    );

    await controller.start();
    final String? transcript = await controller.transcribeAudio(<int>[
      1,
      2,
      3,
    ], 'recording.m4a');

    expect(transcript, isNull);
    expect(controller.state.status, InterviewViewStatus.active);
    expect(controller.state.errorMessage, isNull);
    expect(controller.state.isTranscribing, isFalse);
  });
}

class _FakeInterviewRepository implements InterviewRepository {
  _FakeInterviewRepository({this.shouldFailTranscription = false});

  final bool shouldFailTranscription;

  @override
  Future<InterviewSessionDetailRecord> getSession(String sessionId) async {
    return const InterviewSessionDetailRecord(
      sessionId: 'session-1',
      status: 'completed',
      companyId: 'bumn_taspen',
      targetRole: 'Management Trainee',
      mode: 'coaching',
      responseStyle: 'text',
      messages: <InterviewMessage>[],
    );
  }

  @override
  Future<List<InterviewSessionSummaryRecord>> listSessions() async {
    return const <InterviewSessionSummaryRecord>[];
  }

  @override
  String getQuestionAudioUrl({
    required String sessionId,
    required String turnId,
  }) {
    return 'https://example.test/interview/$sessionId/questions/$turnId/audio';
  }

  @override
  Future<String> transcribeAnswerAudio({
    required String sessionId,
    required List<int> audioBytes,
    required String filename,
  }) async {
    if (shouldFailTranscription) {
      throw Exception('transcription unavailable');
    }
    return 'Transkrip jawaban suara.';
  }

  @override
  Future<InterviewStartResult> startSession(
    InterviewLaunchConfig config,
  ) async {
    return InterviewStartResult(
      sessionId: 'session-1',
      status: 'active',
      openingQuestion: InterviewMessage(
        id: 'question-1',
        author: InterviewMessageAuthor.interviewer,
        text: 'Perkenalkan diri Anda.',
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<InterviewTurnResult> submitAnswer({
    required String sessionId,
    required String answer,
    required String idempotencyKey,
  }) async {
    return InterviewTurnResult(
      sessionId: sessionId,
      status: 'active',
      evaluation: const InterviewEvaluation(
        overallScore: 82,
        strengths: <String>['Jelas'],
        improvements: <String>['Tambahkan dampak terukur'],
      ),
      nextQuestion: InterviewMessage(
        id: 'question-2',
        author: InterviewMessageAuthor.interviewer,
        text: 'Mengapa memilih perusahaan ini?',
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<InterviewFinalSummary> completeSession(String sessionId) async {
    return const InterviewFinalSummary(
      overallScore: 82,
      strengths: <String>['Jelas'],
      improvements: <String>['Tambahkan dampak terukur'],
      answerCount: 1,
    );
  }
}
