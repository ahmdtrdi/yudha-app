import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

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
}
