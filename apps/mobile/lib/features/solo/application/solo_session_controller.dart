import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

enum SoloReaction { idle, attack, hit }

class SoloSessionState {
  const SoloSessionState({
    this.session,
    this.openedQuestion,
    this.feedback,
    this.loading = false,
    this.submitting = false,
    this.questionVisible = false,
    this.hintVisible = false,
    this.hintLoading = false,
    this.selectedOption,
    this.reaction = SoloReaction.idle,
    this.error,
  });

  final SoloSession? session;
  final SoloQuestion? openedQuestion;
  final SoloAnswerFeedback? feedback;
  final bool loading;
  final bool submitting;
  final bool questionVisible;
  final bool hintVisible;
  final bool hintLoading;
  final int? selectedOption;
  final SoloReaction reaction;
  final String? error;

  bool get showFeedback => feedback != null;

  SoloSessionState copyWith({
    SoloSession? session,
    SoloQuestion? openedQuestion,
    SoloAnswerFeedback? feedback,
    bool clearQuestion = false,
    bool clearFeedback = false,
    bool? loading,
    bool? submitting,
    bool? questionVisible,
    bool? hintVisible,
    bool? hintLoading,
    int? selectedOption,
    bool clearSelection = false,
    SoloReaction? reaction,
    String? error,
    bool clearError = false,
  }) => SoloSessionState(
    session: session ?? this.session,
    openedQuestion: clearQuestion
        ? null
        : openedQuestion ?? this.openedQuestion,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    questionVisible: questionVisible ?? this.questionVisible,
    hintVisible: hintVisible ?? this.hintVisible,
    hintLoading: hintLoading ?? this.hintLoading,
    selectedOption: clearSelection
        ? null
        : selectedOption ?? this.selectedOption,
    reaction: reaction ?? this.reaction,
    error: clearError ? null : error ?? this.error,
  );
}

class SoloSessionController extends StateNotifier<SoloSessionState> {
  SoloSessionController(this.repository) : super(const SoloSessionState());
  final SoloRepository repository;
  final Map<String, String> _questionHints = <String, String>{};
  final Map<String, int> _selectedOptions = <String, int>{};
  final Map<String, Stopwatch> _activeTimers = <String, Stopwatch>{};
  final Map<String, Duration> _backgroundDurations = <String, Duration>{};
  final Map<String, DateTime> _backgroundStartedAt = <String, DateTime>{};
  Timer? _reactionTimer;
  bool _dismissedPendingAnswer = false;

  Future<bool> start({
    required SoloQuestionCount count,
    required String characterId,
    SoloMechanicMode mechanicMode = SoloMechanicMode.standard,
    SoloQuestionSelection questionSelection =
        const SoloBalancedQuestionSelection(),
    String? recommendationId,
  }) async {
    state = const SoloSessionState(loading: true);
    try {
      state = SoloSessionState(
        session: await repository.create(
          questionCount: count,
          characterId: characterId,
          mechanicMode: mechanicMode,
          questionSelection: questionSelection,
          recommendationId: recommendationId,
        ),
      );
      return true;
    } catch (error) {
      state = SoloSessionState(error: error.toString());
      return false;
    }
  }

  Future<bool> resume(String sessionId) async {
    state = const SoloSessionState(loading: true);
    try {
      state = SoloSessionState(session: await repository.get(sessionId));
      return true;
    } catch (error) {
      state = SoloSessionState(error: error.toString());
      return false;
    }
  }

  Future<void> openCard(SoloHandCard card) async {
    if (state.submitting ||
        state.showFeedback ||
        state.reaction != SoloReaction.idle ||
        state.session == null) {
      return;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      SoloQuestion question = await repository.open(
        state.session!.id,
        card.sessionQuestionId,
      );
      if (state.session?.mechanicMode == SoloMechanicMode.focus) {
        question = question.copyWith(clearDeadline: true, timeLimitSeconds: 0);
      } else if (state.session?.mechanicMode == SoloMechanicMode.speed &&
          question.openedAt != null &&
          question.deadlineAt != null) {
        final int halfSec = (question.timeLimitSeconds / 2).ceil().clamp(1, 9999);
        question = question.copyWith(
          timeLimitSeconds: halfSec,
          deadlineAt: question.openedAt!.add(Duration(seconds: halfSec)),
        );
      }
      final String? knownHint = _questionHints[card.sessionQuestionId];
      final Stopwatch activeTimer = _activeTimers.putIfAbsent(
        card.sessionQuestionId,
        Stopwatch.new,
      );
      activeTimer.start();
      state = state.copyWith(
        openedQuestion: knownHint == null
            ? question
            : question.withHint(knownHint),
        submitting: false,
        questionVisible: true,
        hintVisible: knownHint != null,
        selectedOption: _selectedOptions[card.sessionQuestionId],
        clearSelection: !_selectedOptions.containsKey(card.sessionQuestionId),
      );
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  void closeQuestion() {
    if (!state.showFeedback) {
      final String? questionId = state.openedQuestion?.sessionQuestionId;
      if (questionId != null) {
        _activeTimers[questionId]?.stop();
      }
      _dismissedPendingAnswer = state.submitting;
      state = state.copyWith(questionVisible: false);
    }
  }

  void pauseActiveTiming() {
    final SoloQuestion? question = state.openedQuestion;
    if (question == null || !state.questionVisible || state.showFeedback) {
      return;
    }
    _activeTimers[question.sessionQuestionId]?.stop();
    _backgroundStartedAt.putIfAbsent(question.sessionQuestionId, DateTime.now);
  }

  void resumeActiveTiming() {
    final SoloQuestion? question = state.openedQuestion;
    if (question == null || !state.questionVisible || state.showFeedback) {
      return;
    }
    final DateTime? startedAt = _backgroundStartedAt.remove(
      question.sessionQuestionId,
    );
    if (startedAt != null) {
      _backgroundDurations.update(
        question.sessionQuestionId,
        (Duration current) => current + DateTime.now().difference(startedAt),
        ifAbsent: () => DateTime.now().difference(startedAt),
      );
    }
    _activeTimers[question.sessionQuestionId]?.start();
  }

  Future<void> showHint() async {
    final SoloSession? session = state.session;
    final SoloQuestion? question = state.openedQuestion;
    if (state.showFeedback ||
        state.submitting ||
        state.hintLoading ||
        session == null ||
        question == null) {
      return;
    }
    state = state.copyWith(hintLoading: true, clearError: true);
    try {
      final SoloHint response = await repository.requestHint(
        session.id,
        question.sessionQuestionId,
      );
      final String hintText = response.hint.trim().isNotEmpty
          ? response.hint
          : 'Gunakan teknik eliminasi pada opsi yang paling tidak relevan, lalu periksa kata kunci utama.';
      _questionHints[question.sessionQuestionId] = hintText;
      final bool stillShowingQuestion =
          state.openedQuestion?.sessionQuestionId == question.sessionQuestionId;
      state = state.copyWith(
        openedQuestion: stillShowingQuestion
            ? question.withHint(hintText)
            : state.openedQuestion,
        hintVisible: stillShowingQuestion ? true : state.hintVisible,
        hintLoading: false,
      );
    } catch (error) {
      final String message = error.toString();
      if (message.contains('ACTION_REJECTED') ||
          message.contains('unavailable') ||
          message.contains('not available')) {
        const String fallbackHint =
            'Gunakan teknik eliminasi pada opsi yang paling tidak relevan, lalu periksa kata kunci utama.';
        _questionHints[question.sessionQuestionId] = fallbackHint;
        final bool stillShowingQuestion =
            state.openedQuestion?.sessionQuestionId == question.sessionQuestionId;
        state = state.copyWith(
          openedQuestion: stillShowingQuestion
              ? question.withHint(fallbackHint)
              : state.openedQuestion,
          hintVisible: stillShowingQuestion ? true : state.hintVisible,
          hintLoading: false,
        );
      } else {
        state = state.copyWith(hintLoading: false, error: error.toString());
      }
    }
  }

  void select(int index) {
    if (!state.submitting && !state.showFeedback) {
      final questionId = state.openedQuestion?.sessionQuestionId;
      if (questionId != null) _selectedOptions[questionId] = index;
      state = state.copyWith(selectedOption: index);
    }
  }

  Future<void> selectAndSubmit(int index) async {
    select(index);
    await submit();
  }

  Future<void> submit() => _answer(state.selectedOption);
  Future<void> timeout() => _answer(null);

  Future<void> _answer(int? option) async {
    final session = state.session;
    final question = state.openedQuestion;
    if (session == null ||
        question == null ||
        state.submitting ||
        state.showFeedback) {
      return;
    }
    if (session.mechanicMode == SoloMechanicMode.focus && option == null) {
      return;
    }
    if (option == null &&
        question.deadlineAt != null &&
        DateTime.now().isBefore(question.deadlineAt!)) {
      return;
    }
    _dismissedPendingAnswer = false;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final Stopwatch? activeTimer = _activeTimers[question.sessionQuestionId];
      activeTimer?.stop();
      final response = await repository.answer(
        session.id,
        question.sessionQuestionId,
        option,
        clientActiveResponseTimeMs: activeTimer?.elapsedMilliseconds,
        backgroundDurationMs:
            (_backgroundDurations[question.sessionQuestionId] ?? Duration.zero)
                .inMilliseconds,
      );
      if (_dismissedPendingAnswer) {
        _discardCommittedQuestion(response);
        return;
      }
      state = state.copyWith(
        session: response.session,
        feedback: response.feedback,
        submitting: false,
        questionVisible: true,
        reaction: SoloReaction.idle,
      );
    } catch (error) {
      _dismissedPendingAnswer = false;
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  void _discardCommittedQuestion(SoloAnswerResponse response) {
    final String questionId = response.feedback.sessionQuestionId;
    _questionHints.remove(questionId);
    _selectedOptions.remove(questionId);
    _activeTimers.remove(questionId);
    _backgroundDurations.remove(questionId);
    _backgroundStartedAt.remove(questionId);
    _dismissedPendingAnswer = false;
    final SoloReaction reaction = response.feedback.isCorrect
        ? SoloReaction.attack
        : SoloReaction.hit;
    state = state.copyWith(
      session: response.session,
      clearQuestion: true,
      clearFeedback: true,
      clearSelection: true,
      submitting: false,
      questionVisible: false,
      hintVisible: false,
      hintLoading: false,
      reaction: reaction,
      clearError: true,
    );
    _reactionTimer?.cancel();
    _reactionTimer = Timer(const Duration(milliseconds: 850), () {
      state = state.copyWith(reaction: SoloReaction.idle);
    });
  }

  void next() {
    final SoloAnswerFeedback? feedback = state.feedback;
    if (feedback == null || state.submitting) return;
    final questionId = state.openedQuestion?.sessionQuestionId;
    if (questionId != null) {
      _questionHints.remove(questionId);
      _selectedOptions.remove(questionId);
      _activeTimers.remove(questionId);
      _backgroundDurations.remove(questionId);
      _backgroundStartedAt.remove(questionId);
    }
    final SoloReaction reaction = feedback.isCorrect
        ? SoloReaction.attack
        : SoloReaction.hit;
    _reactionTimer?.cancel();
    state = state.copyWith(
      clearQuestion: true,
      clearFeedback: true,
      clearSelection: true,
      questionVisible: false,
      hintVisible: false,
      hintLoading: false,
      reaction: reaction,
      clearError: true,
    );
    _reactionTimer = Timer(const Duration(milliseconds: 850), () {
      state = state.copyWith(reaction: SoloReaction.idle);
    });
  }

  Future<bool> stop() async {
    final session = state.session;
    if (session == null || !session.isActive) return false;
    state = state.copyWith(submitting: true);
    try {
      state = SoloSessionState(session: await repository.stop(session.id));
      return true;
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
      return false;
    }
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    super.dispose();
  }
}
