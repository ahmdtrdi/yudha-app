import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

enum PracticeViewStatus { loading, ready, submitting, completed, error }

class PracticeState {
  const PracticeState({
    required this.status,
    required this.sessionId,
    required this.topics,
    required this.selectedTopicId,
    required this.questions,
    required this.currentQuestionIndex,
    required this.selectedOptionId,
    required this.isCurrentQuestionSubmitted,
    required this.correctAnswers,
    required this.correctOptionIndex,
    required this.answerExplanation,
    required this.hintState,
    required this.questionStartedAt,
    required this.summary,
    required this.overallProgressPercent,
    required this.recentActivities,
    required this.errorMessage,
  });

  factory PracticeState.initial() {
    return const PracticeState(
      status: PracticeViewStatus.loading,
      sessionId: null,
      topics: <PracticeTopic>[],
      selectedTopicId: null,
      questions: <PracticeQuestion>[],
      currentQuestionIndex: 0,
      selectedOptionId: null,
      isCurrentQuestionSubmitted: false,
      correctAnswers: 0,
      correctOptionIndex: null,
      answerExplanation: null,
      hintState: PracticeHintState.locked,
      questionStartedAt: null,
      summary: null,
      overallProgressPercent: 0,
      recentActivities: <PracticeRecentActivity>[],
      errorMessage: null,
    );
  }

  final PracticeViewStatus status;
  final String? sessionId;
  final List<PracticeTopic> topics;
  final String? selectedTopicId;
  final List<PracticeQuestion> questions;
  final int currentQuestionIndex;
  final String? selectedOptionId;
  final bool isCurrentQuestionSubmitted;
  final int correctAnswers;
  final int? correctOptionIndex;
  final String? answerExplanation;
  final PracticeHintState hintState;
  final DateTime? questionStartedAt;
  final PracticeSessionSummary? summary;
  final int overallProgressPercent;
  final List<PracticeRecentActivity> recentActivities;
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
    String? sessionId,
    bool clearSession = false,
    List<PracticeTopic>? topics,
    String? selectedTopicId,
    List<PracticeQuestion>? questions,
    int? currentQuestionIndex,
    String? selectedOptionId,
    bool resetSelectedOption = false,
    bool? isCurrentQuestionSubmitted,
    int? correctAnswers,
    int? correctOptionIndex,
    bool clearCorrectOption = false,
    String? answerExplanation,
    bool clearAnswerExplanation = false,
    PracticeHintState? hintState,
    DateTime? questionStartedAt,
    bool clearQuestionStartedAt = false,
    PracticeSessionSummary? summary,
    bool clearSummary = false,
    int? overallProgressPercent,
    List<PracticeRecentActivity>? recentActivities,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PracticeState(
      status: status ?? this.status,
      sessionId: clearSession ? null : sessionId ?? this.sessionId,
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
      correctOptionIndex: clearCorrectOption
          ? null
          : correctOptionIndex ?? this.correctOptionIndex,
      answerExplanation: clearAnswerExplanation
          ? null
          : answerExplanation ?? this.answerExplanation,
      hintState: hintState ?? this.hintState,
      questionStartedAt: clearQuestionStartedAt
          ? null
          : questionStartedAt ?? this.questionStartedAt,
      summary: clearSummary ? null : summary ?? this.summary,
      overallProgressPercent:
          overallProgressPercent ?? this.overallProgressPercent,
      recentActivities: recentActivities ?? this.recentActivities,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
