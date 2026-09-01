import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.sessionQuestionId,
    required this.topicId,
    required this.topicName,
    required this.prompt,
    required this.options,
    required this.hint,
    required this.questionOrder,
    required this.timeLimitSeconds,
    this.questionRevisionId,
    this.skillId,
    this.hintAvailable = true,
  });

  final String id;
  final String sessionQuestionId;
  final String topicId;
  final String topicName;
  final String prompt;
  final List<PracticeOption> options;
  final String hint;
  final int questionOrder;
  final int timeLimitSeconds;
  final String? questionRevisionId;
  final String? skillId;
  final bool hintAvailable;

  PracticeQuestion copyWith({String? hint}) {
    return PracticeQuestion(
      id: id,
      sessionQuestionId: sessionQuestionId,
      topicId: topicId,
      topicName: topicName,
      prompt: prompt,
      options: options,
      hint: hint ?? this.hint,
      questionOrder: questionOrder,
      timeLimitSeconds: timeLimitSeconds,
      questionRevisionId: questionRevisionId,
      skillId: skillId,
      hintAvailable: hintAvailable,
    );
  }
}
