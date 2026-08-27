import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/application/live_interview_coordinator.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

class InterviewController extends StateNotifier<InterviewState> {
  InterviewController({
    required InterviewRepository repository,
    required InterviewLaunchConfig config,
    void Function(String sessionId)? onSessionChanged,
  }) : _repository = repository,
       _onSessionChanged = onSessionChanged,
       super(InterviewState.initial(config));

  final InterviewRepository _repository;
  final void Function(String sessionId)? _onSessionChanged;
  LiveInterviewCoordinator? _liveCoordinator;

  void attachLiveCoordinator(LiveInterviewCoordinator coordinator) {
    _liveCoordinator = coordinator;
  }

  Future<void> start() async {
    if (state.status == InterviewViewStatus.starting ||
        state.status == InterviewViewStatus.active) {
      return;
    }

    final String? resumeSessionId = state.config.resumeSessionId;
    if (resumeSessionId != null && resumeSessionId.trim().isNotEmpty) {
      await resume(resumeSessionId);
      return;
    }

    state = InterviewState.initial(state.config).copyWith(
      status: InterviewViewStatus.starting,
      clearError: true,
      clearLatestEvaluation: true,
      clearFinalSummary: true,
      clearPendingAnswer: true,
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
      _onSessionChanged?.call(result.sessionId);
      await _startLiveVoiceIfNeeded();
    } catch (error) {
      state = state.copyWith(
        status: InterviewViewStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> resume(String sessionId) async {
    if (sessionId.trim().isEmpty ||
        state.status == InterviewViewStatus.starting ||
        state.status == InterviewViewStatus.submitting) {
      return;
    }

    state = InterviewState.initial(state.config).copyWith(
      status: InterviewViewStatus.starting,
      sessionId: sessionId,
      clearError: true,
      clearLatestEvaluation: true,
      clearFinalSummary: true,
      clearPendingAnswer: true,
    );
    try {
      final InterviewSessionDetailRecord detail = await _repository.getSession(
        sessionId,
      );
      _applySessionDetail(detail);
      _onSessionChanged?.call(sessionId);
      await _startLiveVoiceIfNeeded();
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
        final PendingInterviewAnswer? pending = state.pendingAnswer;
        if (pending != null && !_isPendingResolved(detail, pending)) {
          state = state.copyWith(status: InterviewViewStatus.active);
          await retryPendingAnswer();
          return;
        }
        _applySessionDetail(detail, clearPendingAnswer: true);
      } catch (error) {
        state = state.copyWith(
          status: InterviewViewStatus.active,
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
      id: _newIdempotencyKey(),
      author: InterviewMessageAuthor.candidate,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    final PendingInterviewAnswer pending = PendingInterviewAnswer(
      text: trimmed,
      idempotencyKey: candidateMessage.id,
      localMessageId: candidateMessage.id,
    );
    state = state.copyWith(
      status: InterviewViewStatus.submitting,
      messages: <InterviewMessage>[...state.messages, candidateMessage],
      pendingAnswer: pending,
      clearError: true,
      clearLatestEvaluation: true,
    );

    await _submitPendingAnswer(pending);
  }

  Future<void> retryPendingAnswer() async {
    final PendingInterviewAnswer? current = state.pendingAnswer;
    if (current == null ||
        state.sessionId == null ||
        state.status == InterviewViewStatus.submitting) {
      return;
    }
    final PendingInterviewAnswer pending = current.requiresNewKey
        ? current.copyWith(
            idempotencyKey: _newIdempotencyKey(),
            requiresNewKey: false,
          )
        : current;
    state = state.copyWith(pendingAnswer: pending);
    await _submitPendingAnswer(pending, allowFreshKeyFallback: true);
  }

  Future<void> _submitPendingAnswer(
    PendingInterviewAnswer pending, {
    bool allowFreshKeyFallback = false,
  }) async {
    final String? sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    state = state.copyWith(
      status: InterviewViewStatus.submitting,
      clearError: true,
    );

    try {
      final InterviewTurnResult result = await _repository.submitAnswer(
        sessionId: sessionId,
        answer: pending.text,
        idempotencyKey: pending.idempotencyKey,
      );
      final List<InterviewMessage> nextMessages = state.messages
          .map(
            (InterviewMessage message) =>
                message.id == pending.localMessageId &&
                    result.evaluation != null
                ? message.copyWith(evaluation: result.evaluation)
                : message,
          )
          .toList(growable: true);
      if (result.nextQuestion != null &&
          !nextMessages.any(
            (InterviewMessage message) => message.id == result.nextQuestion!.id,
          )) {
        nextMessages.add(result.nextQuestion!);
      }
      state = state.copyWith(
        status: result.status == 'completed'
            ? InterviewViewStatus.completed
            : InterviewViewStatus.active,
        messages: nextMessages,
        latestEvaluation: result.evaluation,
        finalSummary: result.finalSummary,
        clearPendingAnswer: true,
      );
      _onSessionChanged?.call(sessionId);
    } on InterviewAnswerRetryRequiredException catch (error) {
      if (allowFreshKeyFallback) {
        final PendingInterviewAnswer freshPending = pending.copyWith(
          idempotencyKey: _newIdempotencyKey(),
          requiresNewKey: false,
        );
        state = state.copyWith(
          status: InterviewViewStatus.active,
          pendingAnswer: freshPending,
        );
        await _submitPendingAnswer(freshPending);
        return;
      }
      state = state.copyWith(
        status: InterviewViewStatus.active,
        pendingAnswer: pending.copyWith(requiresNewKey: true),
        errorMessage: error.toString(),
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

    await _liveCoordinator?.stop();
    state = state.copyWith(status: InterviewViewStatus.submitting);
    try {
      final InterviewFinalSummary summary = await _repository.completeSession(
        sessionId,
      );
      state = state.copyWith(
        status: InterviewViewStatus.completed,
        finalSummary: summary,
      );
      _onSessionChanged?.call(sessionId);
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

  Future<void> beginLivePushToTalk() async {
    await _liveCoordinator?.beginPushToTalk();
  }

  Future<void> endLivePushToTalk() async {
    await _liveCoordinator?.endPushToTalk();
  }

  Future<void> cancelLivePushToTalk() async {
    await _liveCoordinator?.cancelPushToTalk();
  }

  Future<void> reconnectLiveVoice() async {
    await _liveCoordinator?.reconnect();
  }

  Future<void> switchLiveVoiceToText() async {
    await _liveCoordinator?.switchToText();
  }

  void updateLivePhase(
    LiveInterviewPhase phase, {
    String? errorMessage,
    bool clearError = false,
  }) {
    state = state.copyWith(
      livePhase: phase,
      liveErrorMessage: errorMessage,
      clearLiveError: clearError,
      isRecording: phase == LiveInterviewPhase.candidateSpeaking,
      isTranscribing: phase == LiveInterviewPhase.transcribing,
    );
  }

  void updateLiveRecordingDuration(Duration duration) {
    state = state.copyWith(liveRecordingDuration: duration);
  }

  void useTextFallback() {
    state = state.copyWith(
      useTextFallback: true,
      livePhase: LiveInterviewPhase.degraded,
      isRecording: false,
      isTranscribing: false,
      liveRecordingDuration: Duration.zero,
    );
  }

  void applyLiveTranscript(String answerId, String text) {
    if (state.messages.any(
      (InterviewMessage message) => message.id == answerId,
    )) {
      return;
    }
    state = state.copyWith(
      messages: <InterviewMessage>[
        ...state.messages,
        InterviewMessage(
          id: answerId,
          author: InterviewMessageAuthor.candidate,
          text: text,
          createdAt: DateTime.now(),
        ),
      ],
      liveTranscript: text,
      clearError: true,
    );
  }

  void applyLiveEvaluation(String answerId, InterviewEvaluation evaluation) {
    state = state.copyWith(
      messages: state.messages
          .map(
            (InterviewMessage message) => message.id == answerId
                ? message.copyWith(evaluation: evaluation)
                : message,
          )
          .toList(growable: false),
      latestEvaluation: evaluation,
    );
  }

  void applyLiveQuestion(String turnId, String text) {
    if (turnId.isEmpty ||
        state.messages.any(
          (InterviewMessage message) => message.id == turnId,
        )) {
      return;
    }
    state = state.copyWith(
      messages: <InterviewMessage>[
        ...state.messages,
        InterviewMessage(
          id: turnId,
          author: InterviewMessageAuthor.interviewer,
          text: text,
          createdAt: DateTime.now(),
          audioAvailable: true,
        ),
      ],
      clearLiveTranscript: true,
    );
  }

  void applyLiveCompletion(InterviewFinalSummary summary) {
    state = state.copyWith(
      status: InterviewViewStatus.completed,
      livePhase: LiveInterviewPhase.completed,
      finalSummary: summary,
      isRecording: false,
      isTranscribing: false,
      liveRecordingDuration: Duration.zero,
    );
    final String? sessionId = state.sessionId;
    if (sessionId != null) {
      _onSessionChanged?.call(sessionId);
    }
  }

  Future<String?> transcribeAudio(List<int> bytes, String filename) async {
    final String? sessionId = state.sessionId;
    if (sessionId == null) {
      return null;
    }

    state = state.copyWith(
      isTranscribing: true,
      clearError: true,
      clearTranscriptionError: true,
    );

    try {
      final String transcript = await _repository.transcribeAnswerAudio(
        sessionId: sessionId,
        audioBytes: bytes,
        filename: filename,
      );
      state = state.copyWith(
        isTranscribing: false,
        transcriptionText: transcript,
        clearTranscriptionError: true,
      );
      return transcript;
    } catch (error) {
      state = state.copyWith(
        isTranscribing: false,
        clearTranscriptionText: true,
        transcriptionErrorMessage: error.toString(),
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

  Future<void> _startLiveVoiceIfNeeded() async {
    final LiveInterviewCoordinator? coordinator = _liveCoordinator;
    final String? sessionId = state.sessionId;
    final InterviewMessage? question = state.currentQuestion;
    if (coordinator == null ||
        state.config.responseStyle != 'voice' ||
        state.useTextFallback ||
        sessionId == null ||
        question == null ||
        state.status != InterviewViewStatus.active) {
      return;
    }
    await coordinator.start(
      sessionId: sessionId,
      currentQuestionId: question.id,
    );
  }

  @override
  void dispose() {
    final LiveInterviewCoordinator? coordinator = _liveCoordinator;
    if (coordinator != null) {
      coordinator.dispose();
    }
    super.dispose();
  }

  void _applySessionDetail(
    InterviewSessionDetailRecord detail, {
    bool clearPendingAnswer = false,
  }) {
    InterviewEvaluation? latestEvaluation;
    for (final InterviewMessage message in detail.messages.reversed) {
      if (message.evaluation != null) {
        latestEvaluation = message.evaluation;
        break;
      }
    }
    state = state.copyWith(
      status: detail.status == 'completed'
          ? InterviewViewStatus.completed
          : InterviewViewStatus.active,
      sessionId: detail.sessionId,
      messages: detail.messages,
      latestEvaluation: latestEvaluation,
      finalSummary: detail.finalSummary,
      clearError: true,
      clearPendingAnswer: clearPendingAnswer,
    );
  }

  bool _isPendingResolved(
    InterviewSessionDetailRecord detail,
    PendingInterviewAnswer pending,
  ) {
    if (detail.status == 'completed') {
      return true;
    }
    final int answerIndex = detail.messages.lastIndexWhere(
      (InterviewMessage message) =>
          message.author == InterviewMessageAuthor.candidate &&
          message.text.trim() == pending.text,
    );
    if (answerIndex < 0) {
      return false;
    }
    final InterviewMessage answer = detail.messages[answerIndex];
    if (answer.evaluation != null) {
      return true;
    }
    return detail.messages
        .skip(answerIndex + 1)
        .any(
          (InterviewMessage message) =>
              message.author == InterviewMessageAuthor.interviewer,
        );
  }

  int _idempotencyCounter = 0;

  String _newIdempotencyKey() {
    _idempotencyCounter += 1;
    return 'answer-${DateTime.now().microsecondsSinceEpoch}-$_idempotencyCounter';
  }
}
