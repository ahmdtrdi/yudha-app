import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class PracticeController extends StateNotifier<PracticeState> {
  PracticeController({required PracticeRepository repository})
    : _repository = repository,
      super(PracticeState.initial()) {
    load();
  }

  final PracticeRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: PracticeViewStatus.loading,
      clearError: true,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
    );

    try {
      final List<PracticeTopic> topics = await _repository.fetchTopics();
      final PracticeQuestion questionOfDay = await _repository
          .fetchQuestionOfDay();

      if (topics.isEmpty) {
        state = state.copyWith(
          status: PracticeViewStatus.error,
          errorMessage: 'No practice topics available yet.',
          updateQuestionOfDay: true,
          questionOfDay: questionOfDay,
        );
        return;
      }

      final PracticeTopic selectedTopic = topics.first;
      final List<PracticeQuestion> questions = await _repository.fetchQuestions(
        topicId: selectedTopic.id,
      );

      if (questions.isEmpty) {
        state = state.copyWith(
          status: PracticeViewStatus.error,
          topics: topics,
          selectedTopicId: selectedTopic.id,
          errorMessage: 'No questions found for this topic.',
          updateQuestionOfDay: true,
          questionOfDay: questionOfDay,
        );
        return;
      }

      state = state.copyWith(
        status: PracticeViewStatus.ready,
        topics: topics,
        selectedTopicId: selectedTopic.id,
        questions: questions,
        currentQuestionIndex: 0,
        correctAnswers: 0,
        hintState: PracticeHintState.locked,
        isCurrentQuestionSubmitted: false,
        resetSelectedOption: true,
        updateQuestionOfDay: true,
        questionOfDay: questionOfDay,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: PracticeViewStatus.error,
        errorMessage: 'Failed to load practice session. Please retry.',
      );
    }
  }

  Future<void> reload() async {
    await load();
  }

  Future<void> selectTopic(String topicId) async {
    if (topicId == state.selectedTopicId) {
      return;
    }

    PracticeTopic? targetTopic;
    for (final PracticeTopic topic in state.topics) {
      if (topic.id == topicId) {
        targetTopic = topic;
        break;
      }
    }

    if (targetTopic == null || targetTopic.isLocked) {
      return;
    }

    state = state.copyWith(
      status: PracticeViewStatus.loading,
      selectedTopicId: topicId,
      clearError: true,
    );

    try {
      final List<PracticeQuestion> questions = await _repository.fetchQuestions(
        topicId: topicId,
      );

      if (questions.isEmpty) {
        state = state.copyWith(
          status: PracticeViewStatus.error,
          errorMessage: 'No questions found for this topic.',
        );
        return;
      }

      state = state.copyWith(
        status: PracticeViewStatus.ready,
        questions: questions,
        currentQuestionIndex: 0,
        correctAnswers: 0,
        hintState: PracticeHintState.locked,
        isCurrentQuestionSubmitted: false,
        resetSelectedOption: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: PracticeViewStatus.error,
        errorMessage: 'Failed to switch topic. Please retry.',
      );
    }
  }

  void startQuestionOfDay() {
    final PracticeQuestion? qotd = state.questionOfDay;
    if (qotd == null) {
      return;
    }

    state = state.copyWith(
      status: PracticeViewStatus.ready,
      selectedTopicId: qotd.topicId,
      questions: <PracticeQuestion>[qotd],
      currentQuestionIndex: 0,
      correctAnswers: 0,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
      clearError: true,
    );
  }

  void selectOption(String optionId) {
    if (state.status != PracticeViewStatus.ready ||
        state.isCurrentQuestionSubmitted) {
      return;
    }

    final PracticeQuestion? question = state.currentQuestion;
    if (question == null) {
      return;
    }

    final bool optionExists = question.options.any(
      (PracticeOption option) => option.id == optionId,
    );
    if (!optionExists) {
      return;
    }

    state = state.copyWith(selectedOptionId: optionId);
  }

  void submitCurrentAnswer() {
    if (state.status != PracticeViewStatus.ready ||
        state.isCurrentQuestionSubmitted ||
        state.selectedOptionId == null) {
      return;
    }

    final PracticeQuestion? question = state.currentQuestion;
    if (question == null) {
      return;
    }

    final bool isCorrect = question.options.any(
      (PracticeOption option) =>
          option.id == state.selectedOptionId && option.isCorrect,
    );

    final int nextCorrectAnswers = state.correctAnswers + (isCorrect ? 1 : 0);

    state = state.copyWith(
      isCurrentQuestionSubmitted: true,
      correctAnswers: nextCorrectAnswers,
      status: state.isLastQuestion
          ? PracticeViewStatus.completed
          : PracticeViewStatus.ready,
    );
  }

  void nextQuestion() {
    if (!state.isCurrentQuestionSubmitted) {
      return;
    }

    if (state.isLastQuestion) {
      state = state.copyWith(status: PracticeViewStatus.completed);
      return;
    }

    state = state.copyWith(
      status: PracticeViewStatus.ready,
      currentQuestionIndex: state.currentQuestionIndex + 1,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
      clearError: true,
    );
  }

  void restartSession() {
    if (state.questions.isEmpty) {
      return;
    }

    state = state.copyWith(
      status: PracticeViewStatus.ready,
      currentQuestionIndex: 0,
      correctAnswers: 0,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
      clearError: true,
    );
  }

  void setHintToWatchAd() {
    if (state.hintState == PracticeHintState.unlocked) {
      return;
    }

    state = state.copyWith(hintState: PracticeHintState.watchAd);
  }

  void setHintToBuy() {
    if (state.hintState == PracticeHintState.unlocked) {
      return;
    }

    state = state.copyWith(hintState: PracticeHintState.buy);
  }

  void unlockHint() {
    if (state.hintState != PracticeHintState.watchAd &&
        state.hintState != PracticeHintState.buy) {
      return;
    }

    state = state.copyWith(hintState: PracticeHintState.unlocked);
  }

  void resetHintState() {
    if (state.hintState == PracticeHintState.unlocked) {
      return;
    }

    state = state.copyWith(hintState: PracticeHintState.locked);
  }
}
