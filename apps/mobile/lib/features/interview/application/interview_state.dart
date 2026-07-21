import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

enum InterviewViewStatus {
  idle,
  starting,
  active,
  submitting,
  completed,
  error,
}

class InterviewState {
  const InterviewState({
    required this.status,
    required this.config,
    required this.messages,
    this.sessionId,
    this.errorMessage,
    this.latestEvaluation,
    this.finalSummary,
    this.isRecording = false,
    this.isTranscribing = false,
    this.transcriptionText,
  });

  factory InterviewState.initial(InterviewLaunchConfig config) {
    return InterviewState(
      status: InterviewViewStatus.idle,
      config: config,
      messages: const <InterviewMessage>[],
    );
  }

  final InterviewViewStatus status;
  final InterviewLaunchConfig config;
  final List<InterviewMessage> messages;
  final String? sessionId;
  final String? errorMessage;
  final InterviewEvaluation? latestEvaluation;
  final InterviewFinalSummary? finalSummary;
  final bool isRecording;
  final bool isTranscribing;
  final String? transcriptionText;

  bool get canSubmit =>
      status == InterviewViewStatus.active && sessionId != null && !isTranscribing;

  InterviewMessage? get currentQuestion {
    for (final InterviewMessage message in messages.reversed) {
      if (message.author == InterviewMessageAuthor.interviewer) {
        return message;
      }
    }
    return null;
  }

  InterviewState copyWith({
    InterviewViewStatus? status,
    InterviewLaunchConfig? config,
    List<InterviewMessage>? messages,
    String? sessionId,
    String? errorMessage,
    InterviewEvaluation? latestEvaluation,
    InterviewFinalSummary? finalSummary,
    bool? isRecording,
    bool? isTranscribing,
    String? transcriptionText,
    bool clearError = false,
    bool clearLatestEvaluation = false,
    bool clearTranscriptionText = false,
  }) {
    return InterviewState(
      status: status ?? this.status,
      config: config ?? this.config,
      messages: messages ?? this.messages,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      latestEvaluation: clearLatestEvaluation
          ? null
          : latestEvaluation ?? this.latestEvaluation,
      finalSummary: finalSummary ?? this.finalSummary,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      transcriptionText: clearTranscriptionText
          ? null
          : transcriptionText ?? this.transcriptionText,
    );
  }
}
