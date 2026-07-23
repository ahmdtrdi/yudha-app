import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

class InterviewController extends StateNotifier<InterviewState> {
  InterviewController({
    required InterviewRepository repository,
    required InterviewLaunchConfig config,
  }) : _repository = repository,
       super(InterviewState.initial(config));

  final InterviewRepository _repository;

  Future<void> start() async {
    if (state.status == InterviewViewStatus.starting ||
        state.status == InterviewViewStatus.active) {
      return;
    }

    state = state.copyWith(
      status: InterviewViewStatus.starting,
      clearError: true,
      clearLatestEvaluation: true,
    );

    try {
      final InterviewStartResult result = await _repository.startSession(
        state.config,
      );
      state = state.copyWith(
        status: InterviewViewStatus.active,
        sessionId: result.sessionId,
        messages: <InterviewMessage>[result.openingQuestion],
      );
    } catch (error) {
      state = state.copyWith(
        status: InterviewViewStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retry() async {
    final String? sessionId = state.sessionId;
    if (sessionId != null) {
      state = state.copyWith(
        status: InterviewViewStatus.starting,
        clearError: true,
      );
      try {
        final InterviewSessionDetailRecord detail = await _repository
            .getSession(sessionId);
        state = state.copyWith(
          status: detail.status == 'completed'
              ? InterviewViewStatus.completed
              : InterviewViewStatus.active,
          messages: detail.messages,
          finalSummary: detail.finalSummary,
        );
      } catch (error) {
        state = state.copyWith(
          status: InterviewViewStatus.error,
          errorMessage: error.toString(),
        );
      }
    } else {
      await start();
    }
  }

  Future<void> submitAnswer(String answer) async {
    final String trimmed = answer.trim();
    final String? sessionId = state.sessionId;
    if (trimmed.isEmpty || sessionId == null || !state.canSubmit) {
      return;
    }

    final InterviewMessage candidateMessage = InterviewMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      author: InterviewMessageAuthor.candidate,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      status: InterviewViewStatus.submitting,
      messages: <InterviewMessage>[...state.messages, candidateMessage],
      clearError: true,
      clearLatestEvaluation: true,
    );

    try {
      final InterviewTurnResult result = await _repository.submitAnswer(
        sessionId: sessionId,
        answer: trimmed,
        idempotencyKey: candidateMessage.id,
      );
      final List<InterviewMessage> nextMessages = <InterviewMessage>[
        ...state.messages,
        if (result.nextQuestion != null) result.nextQuestion!,
      ];
      state = state.copyWith(
        status: result.status == 'completed'
            ? InterviewViewStatus.completed
            : InterviewViewStatus.active,
        messages: nextMessages,
        latestEvaluation: result.evaluation,
        finalSummary: result.finalSummary,
      );
    } catch (error) {
      state = state.copyWith(
        status: InterviewViewStatus.active,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> complete() async {
    final String? sessionId = state.sessionId;
    if (sessionId == null || state.status == InterviewViewStatus.completed) {
      return;
    }

    state = state.copyWith(status: InterviewViewStatus.submitting);
    try {
      final InterviewFinalSummary summary = await _repository.completeSession(
        sessionId,
      );
      state = state.copyWith(
        status: InterviewViewStatus.completed,
        finalSummary: summary,
      );
    } catch (error) {
      state = state.copyWith(
        status: InterviewViewStatus.active,
        errorMessage: error.toString(),
      );
    }
  }

  void setRecording(bool isRecording) {
    state = state.copyWith(isRecording: isRecording);
  }

  Future<String?> transcribeAudio(List<int> bytes, String filename) async {
    final String? sessionId = state.sessionId;
    if (sessionId == null) {
      return null;
    }

    state = state.copyWith(isTranscribing: true, clearError: true);

    try {
      final String transcript = await _repository.transcribeAnswerAudio(
        sessionId: sessionId,
        audioBytes: bytes,
        filename: filename,
      );
      state = state.copyWith(
        isTranscribing: false,
        transcriptionText: transcript,
      );
      return transcript;
    } catch (_) {
      state = state.copyWith(
        isTranscribing: false,
        clearTranscriptionText: true,
      );
      return null;
    }
  }

  String? getQuestionAudioUrl(String turnId) {
    final String? sessionId = state.sessionId;
    if (sessionId == null) {
      return null;
    }
    return _repository.getQuestionAudioUrl(
      sessionId: sessionId,
      turnId: turnId,
    );
  }
}
