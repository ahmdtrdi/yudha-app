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
  final Set<String> _hintedQuestions = <String>{};
  final Map<String, int> _selectedOptions = <String, int>{};

  Future<bool> start({
    required SoloQuestionCount count,
    required String characterId,
  }) async {
    state = const SoloSessionState(loading: true);
    try {
      state = SoloSessionState(
        session: await repository.create(
          questionCount: count,
          characterId: characterId,
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
    if (state.submitting || state.showFeedback || state.session == null) return;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final question = await repository.open(
        state.session!.id,
        card.sessionQuestionId,
      );
      state = state.copyWith(
        openedQuestion: question,
        submitting: false,
        questionVisible: true,
        hintVisible: _hintedQuestions.contains(card.sessionQuestionId),
        selectedOption: _selectedOptions[card.sessionQuestionId],
        clearSelection: !_selectedOptions.containsKey(card.sessionQuestionId),
      );
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  void closeQuestion() {
    if (!state.showFeedback && !state.submitting) {
      state = state.copyWith(questionVisible: false);
    }
  }

  void showHint() {
    if (!state.showFeedback && state.openedQuestion != null) {
      _hintedQuestions.add(state.openedQuestion!.sessionQuestionId);
      state = state.copyWith(hintVisible: true);
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
    if (option == null &&
        question.deadlineAt != null &&
        DateTime.now().isBefore(question.deadlineAt!)) {
      return;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final response = await repository.answer(
        session.id,
        question.sessionQuestionId,
        option,
        _hintedQuestions.contains(question.sessionQuestionId),
      );
      state = state.copyWith(
        session: response.session,
        feedback: response.feedback,
        submitting: false,
        questionVisible: true,
        reaction: response.feedback.isCorrect
            ? SoloReaction.attack
            : SoloReaction.hit,
      );
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  void next() {
    final questionId = state.openedQuestion?.sessionQuestionId;
    if (questionId != null) {
      _hintedQuestions.remove(questionId);
      _selectedOptions.remove(questionId);
    }
    state = state.copyWith(
      clearQuestion: true,
      clearFeedback: true,
      clearSelection: true,
      questionVisible: false,
      hintVisible: false,
      reaction: SoloReaction.idle,
      clearError: true,
    );
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
}
