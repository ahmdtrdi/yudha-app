import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

enum SoloReaction { idle, attack, hit }

class SoloSessionState {
  const SoloSessionState({
    this.session,
    this.loading = false,
    this.submitting = false,
    this.selectedOption,
    this.showFeedback = false,
    this.reaction = SoloReaction.idle,
    this.error,
  });
  final SoloSession? session;
  final bool loading;
  final bool submitting;
  final int? selectedOption;
  final bool showFeedback;
  final SoloReaction reaction;
  final String? error;

  SoloSessionState copyWith({
    SoloSession? session,
    bool? loading,
    bool? submitting,
    int? selectedOption,
    bool clearSelection = false,
    bool? showFeedback,
    SoloReaction? reaction,
    String? error,
    bool clearError = false,
  }) => SoloSessionState(
    session: session ?? this.session,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    selectedOption: clearSelection
        ? null
        : selectedOption ?? this.selectedOption,
    showFeedback: showFeedback ?? this.showFeedback,
    reaction: reaction ?? this.reaction,
    error: clearError ? null : error ?? this.error,
  );
}

class SoloSessionController extends StateNotifier<SoloSessionState> {
  SoloSessionController(this.repository) : super(const SoloSessionState());
  final SoloRepository repository;

  Future<bool> start({
    required SoloQuestionCount count,
    required String characterId,
  }) async {
    state = const SoloSessionState(loading: true);
    try {
      final session = await repository.create(
        questionCount: count,
        characterId: characterId,
      );
      state = SoloSessionState(session: session);
      await _openCurrent();
      return true;
    } catch (error) {
      state = SoloSessionState(error: error.toString());
      return false;
    }
  }

  Future<void> resume(String sessionId) async {
    state = const SoloSessionState(loading: true);
    try {
      state = SoloSessionState(session: await repository.get(sessionId));
      await _openCurrent();
    } catch (error) {
      state = SoloSessionState(error: error.toString());
    }
  }

  void select(int index) {
    if (!state.submitting && !state.showFeedback) {
      state = state.copyWith(selectedOption: index);
    }
  }

  Future<void> submit() => _answer(state.selectedOption);
  Future<void> timeout() => _answer(null);

  Future<void> _answer(int? option) async {
    final session = state.session;
    final question = session?.currentQuestion;
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
      final updated = await repository.answer(
        session.id,
        question.sessionQuestionId,
        option,
      );
      final answered = updated.questions[session.answeredCount];
      state = state.copyWith(
        session: updated,
        submitting: false,
        showFeedback: true,
        reaction: answered.isCorrect == true
            ? SoloReaction.attack
            : SoloReaction.hit,
      );
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  Future<void> next() async {
    state = state.copyWith(
      clearSelection: true,
      showFeedback: false,
      reaction: SoloReaction.idle,
      clearError: true,
    );
    await _openCurrent();
  }

  Future<void> stop() async {
    final session = state.session;
    if (session == null || !session.isActive) return;
    state = state.copyWith(submitting: true);
    try {
      state = SoloSessionState(session: await repository.stop(session.id));
    } catch (error) {
      state = state.copyWith(submitting: false, error: error.toString());
    }
  }

  Future<void> _openCurrent() async {
    final session = state.session;
    final question = session?.currentQuestion;
    if (session == null || question == null || question.openedAt != null) {
      return;
    }
    try {
      await repository.open(session.id, question.sessionQuestionId);
      state = state.copyWith(session: await repository.get(session.id));
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }
}
