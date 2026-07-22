import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class PracticeController extends StateNotifier<PracticeState> {
  PracticeController({
    required PracticeRepository repository,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
       super(PracticeState.initial()) {
    load();
  }

  final PracticeRepository _repository;
  final DateTime Function() _now;

  Future<void> load() async {
    state = state.copyWith(
      status: PracticeViewStatus.loading,
      clearSession: true,
      questions: const <PracticeQuestion>[],
      currentQuestionIndex: 0,
      correctAnswers: 0,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
      clearCorrectOption: true,
      clearAnswerExplanation: true,
      clearQuestionStartedAt: true,
      clearSummary: true,
      clearError: true,
    );

    try {
      final PracticeDashboard dashboard = await _repository.fetchDashboard();
      if (dashboard.topics.isEmpty) {
        state = state.copyWith(
          status: PracticeViewStatus.error,
          topics: const <PracticeTopic>[],
          errorMessage: 'Belum ada kategori latihan yang tersedia.',
          overallProgressPercent: dashboard.overallProgressPercent,
          recentActivities: dashboard.recentActivities,
        );
        return;
      }

      state = state.copyWith(
        status: PracticeViewStatus.ready,
        topics: dashboard.topics,
        overallProgressPercent: dashboard.overallProgressPercent,
        recentActivities: dashboard.recentActivities,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: PracticeViewStatus.error,
        errorMessage: _messageFor(error, 'Gagal memuat latihan. Coba lagi.'),
      );
    }
  }

  Future<void> reload() => load();

  Future<bool> startSession(String topicId) async {
    final PracticeTopic? topic = _findTopic(topicId);
    if (topic == null || topic.isLocked) {
      return false;
    }

    state = state.copyWith(
      status: PracticeViewStatus.loading,
      selectedTopicId: topic.id,
      clearSession: true,
      clearSummary: true,
      clearError: true,
    );

    try {
      final PracticeSession session = await _repository.startSession(
        category: topic.category,
        subcategory: topic.subcategory,
      );
      if (session.questions.length != session.totalQuestions) {
        throw StateError('Jumlah soal sesi tidak sesuai respons server.');
      }

      state = state.copyWith(
        status: PracticeViewStatus.ready,
        sessionId: session.id,
        questions: session.questions,
        currentQuestionIndex: 0,
        correctAnswers: 0,
        hintState: PracticeHintState.locked,
        isCurrentQuestionSubmitted: false,
        resetSelectedOption: true,
        clearCorrectOption: true,
        clearAnswerExplanation: true,
        questionStartedAt: _now(),
        clearSummary: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: PracticeViewStatus.ready,
        errorMessage: _messageFor(
          error,
          'Gagal memulai sesi latihan. Coba lagi.',
        ),
      );
      return false;
    }
  }

  void selectOption(String optionId) {
    if (state.status != PracticeViewStatus.ready ||
        state.isCurrentQuestionSubmitted) {
      return;
    }
    final PracticeQuestion? question = state.currentQuestion;
    if (question == null ||
        !question.options.any(
          (PracticeOption option) => option.id == optionId,
        )) {
      return;
    }
    state = state.copyWith(selectedOptionId: optionId, clearError: true);
  }

  Future<bool> submitCurrentAnswer() async {
    final PracticeQuestion? question = state.currentQuestion;
    final String? sessionId = state.sessionId;
    final String? selectedOptionId = state.selectedOptionId;
    if (state.status != PracticeViewStatus.ready ||
        state.isCurrentQuestionSubmitted ||
        question == null ||
        sessionId == null ||
        selectedOptionId == null) {
      return false;
    }

    final PracticeOption selectedOption = question.options.firstWhere(
      (PracticeOption option) => option.id == selectedOptionId,
    );
    final DateTime startedAt = state.questionStartedAt ?? _now();
    final int responseTimeMs = _now()
        .difference(startedAt)
        .inMilliseconds
        .clamp(0, 2147483647);
    state = state.copyWith(
      status: PracticeViewStatus.submitting,
      clearError: true,
    );

    try {
      final PracticeAnswerResult result = await _repository.submitAnswer(
        sessionId: sessionId,
        sessionQuestionId: question.sessionQuestionId,
        selectedOptionIndex: selectedOption.index,
        responseTimeMs: responseTimeMs,
        usedHint: state.hintState == PracticeHintState.unlocked,
      );
      PracticeSessionSummary? summary;
      if (state.isLastQuestion) {
        try {
          summary = await _repository.finishSession(sessionId: sessionId);
        } catch (_) {
          summary = result.progress;
        }
      }

      state = state.copyWith(
        status: state.isLastQuestion
            ? PracticeViewStatus.completed
            : PracticeViewStatus.ready,
        isCurrentQuestionSubmitted: true,
        correctAnswers: result.progress.correctCount,
        correctOptionIndex: result.correctOptionIndex,
        answerExplanation: result.explanation,
        summary: summary,
        clearQuestionStartedAt: true,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: PracticeViewStatus.ready,
        errorMessage: _messageFor(
          error,
          'Jawaban gagal dikirim. Periksa koneksi lalu coba lagi.',
        ),
      );
      return false;
    }
  }

  void nextQuestion() {
    if (!state.isCurrentQuestionSubmitted || state.isLastQuestion) {
      return;
    }
    state = state.copyWith(
      status: PracticeViewStatus.ready,
      currentQuestionIndex: state.currentQuestionIndex + 1,
      hintState: PracticeHintState.locked,
      isCurrentQuestionSubmitted: false,
      resetSelectedOption: true,
      clearCorrectOption: true,
      clearAnswerExplanation: true,
      questionStartedAt: _now(),
      clearError: true,
    );
  }

  Future<bool> restartSession() {
    final String? topicId = state.selectedTopicId;
    if (topicId == null) {
      return Future<bool>.value(false);
    }
    return startSession(topicId);
  }

  void unlockHint() {
    if (state.status != PracticeViewStatus.ready ||
        state.isCurrentQuestionSubmitted) {
      return;
    }
    state = state.copyWith(hintState: PracticeHintState.unlocked);
  }

  PracticeTopic? _findTopic(String topicId) {
    for (final PracticeTopic topic in state.topics) {
      if (topic.id == topicId) {
        return topic;
      }
    }
    return null;
  }

  String _messageFor(Object error, String fallback) {
    final String message = error.toString().trim();
    return message.isEmpty ? fallback : message;
  }
}
