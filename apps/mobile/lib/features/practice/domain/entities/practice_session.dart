import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';

class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.totalQuestions,
    required this.questions,
  });

  final String id;
  final String category;
  final String? subcategory;
  final int totalQuestions;
  final List<PracticeQuestion> questions;
}

class PracticeAnswerResult {
  const PracticeAnswerResult({
    required this.isCorrect,
    required this.correctOptionIndex,
    required this.explanation,
    required this.scoreGained,
    required this.progress,
  });

  final bool isCorrect;
  final int correctOptionIndex;
  final String? explanation;
  final int scoreGained;
  final PracticeSessionSummary progress;
}

class PracticeSessionSummary {
  const PracticeSessionSummary({
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.accuracy,
    required this.totalScore,
  });

  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final double accuracy;
  final int totalScore;
}
