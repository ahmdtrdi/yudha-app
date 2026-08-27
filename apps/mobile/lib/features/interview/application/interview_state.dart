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

enum LiveInterviewPhase {
  disconnected,
  connecting,
  interviewerSpeaking,
  readyToAnswer,
  candidateSpeaking,
  transcribing,
  evaluating,
  reconnecting,
  degraded,
  completed,
}

class PendingInterviewAnswer {
  const PendingInterviewAnswer({
    required this.text,
    required this.idempotencyKey,
    required this.localMessageId,
    this.requiresNewKey = false,
  });

  final String text;
  final String idempotencyKey;
  final String localMessageId;
  final bool requiresNewKey;

  PendingInterviewAnswer copyWith({
    String? idempotencyKey,
    bool? requiresNewKey,
  }) {
    return PendingInterviewAnswer(
      text: text,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      localMessageId: localMessageId,
      requiresNewKey: requiresNewKey ?? this.requiresNewKey,
    );
  }
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
    this.transcriptionErrorMessage,
    this.pendingAnswer,
    this.livePhase = LiveInterviewPhase.disconnected,
    this.liveRecordingDuration = Duration.zero,
    this.useTextFallback = false,
    this.liveTranscript,
    this.liveErrorMessage,
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
  final String? transcriptionErrorMessage;
  final PendingInterviewAnswer? pendingAnswer;
  final LiveInterviewPhase livePhase;
  final Duration liveRecordingDuration;
  final bool useTextFallback;
  final String? liveTranscript;
  final String? liveErrorMessage;

  bool get canSubmit =>
      status == InterviewViewStatus.active &&
      sessionId != null &&
      !isTranscribing &&
      pendingAnswer == null;

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
    String? transcriptionErrorMessage,
    bool clearError = false,
    bool clearLatestEvaluation = false,
    bool clearTranscriptionText = false,
    bool clearTranscriptionError = false,
    PendingInterviewAnswer? pendingAnswer,
    bool clearPendingAnswer = false,
    bool clearFinalSummary = false,
    LiveInterviewPhase? livePhase,
    Duration? liveRecordingDuration,
    bool? useTextFallback,
    String? liveTranscript,
    String? liveErrorMessage,
    bool clearLiveTranscript = false,
    bool clearLiveError = false,
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
      finalSummary: clearFinalSummary
          ? null
          : finalSummary ?? this.finalSummary,
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      transcriptionText: clearTranscriptionText
          ? null
          : transcriptionText ?? this.transcriptionText,
      transcriptionErrorMessage: clearTranscriptionError
          ? null
          : transcriptionErrorMessage ?? this.transcriptionErrorMessage,
      pendingAnswer: clearPendingAnswer
          ? null
          : pendingAnswer ?? this.pendingAnswer,
      livePhase: livePhase ?? this.livePhase,
      liveRecordingDuration:
          liveRecordingDuration ?? this.liveRecordingDuration,
      useTextFallback: useTextFallback ?? this.useTextFallback,
      liveTranscript: clearLiveTranscript
          ? null
          : liveTranscript ?? this.liveTranscript,
      liveErrorMessage: clearLiveError
          ? null
          : liveErrorMessage ?? this.liveErrorMessage,
    );
  }
}
