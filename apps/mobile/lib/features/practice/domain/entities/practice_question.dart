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
}
