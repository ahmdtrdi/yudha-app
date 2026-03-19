import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

enum PracticeViewStatus { loading, ready, completed, error }

class PracticeState {
  const PracticeState({
    required this.status,
    required this.topics,
    required this.selectedTopicId,
    required this.questions,
    required this.currentQuestionIndex,
    required this.selectedOptionId,
    required this.isCurrentQuestionSubmitted,
    required this.correctAnswers,
    required this.hintState,
    required this.questionOfDay,
    required this.errorMessage,
  });

  factory PracticeState.initial() {
    return const PracticeState(
      status: PracticeViewStatus.loading,
      topics: <PracticeTopic>[],
      selectedTopicId: null,
      questions: <PracticeQuestion>[],
      currentQuestionIndex: 0,
      selectedOptionId: null,
      isCurrentQuestionSubmitted: false,
      correctAnswers: 0,
      hintState: PracticeHintState.locked,
      questionOfDay: null,
      errorMessage: null,
    );
  }

  final PracticeViewStatus status;
  final List<PracticeTopic> topics;
  final String? selectedTopicId;
  final List<PracticeQuestion> questions;
  final int currentQuestionIndex;
  final String? selectedOptionId;
  final bool isCurrentQuestionSubmitted;
  final int correctAnswers;
  final PracticeHintState hintState;
  final PracticeQuestion? questionOfDay;
  final String? errorMessage;

  PracticeQuestion? get currentQuestion {
    if (questions.isEmpty || currentQuestionIndex >= questions.length) {
      return null;
    }
    return questions[currentQuestionIndex];
  }

  PracticeTopic? get selectedTopic {
    if (selectedTopicId == null) {
      return null;
    }

    for (final PracticeTopic topic in topics) {
      if (topic.id == selectedTopicId) {
        return topic;
      }
    }

    return null;
  }

  bool get isLastQuestion {
    if (questions.isEmpty) {
      return false;
    }
    return currentQuestionIndex == questions.length - 1;
  }

  PracticeState copyWith({
    PracticeViewStatus? status,
    List<PracticeTopic>? topics,
    String? selectedTopicId,
    List<PracticeQuestion>? questions,
    int? currentQuestionIndex,
    String? selectedOptionId,
    bool resetSelectedOption = false,
    bool? isCurrentQuestionSubmitted,
    int? correctAnswers,
    PracticeHintState? hintState,
    PracticeQuestion? questionOfDay,
    bool updateQuestionOfDay = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PracticeState(
      status: status ?? this.status,
      topics: topics ?? this.topics,
      selectedTopicId: selectedTopicId ?? this.selectedTopicId,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedOptionId: resetSelectedOption
          ? null
          : selectedOptionId ?? this.selectedOptionId,
      isCurrentQuestionSubmitted:
          isCurrentQuestionSubmitted ?? this.isCurrentQuestionSubmitted,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      hintState: hintState ?? this.hintState,
      questionOfDay: updateQuestionOfDay ? questionOfDay : this.questionOfDay,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

