import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.prompt,
    required this.options,
    required this.hint,
    this.isQuestionOfDay = false,
  });

  final String id;
  final String topicId;
  final String topicName;
  final String prompt;
  final List<PracticeOption> options;
  final String hint;
  final bool isQuestionOfDay;

  PracticeOption? get correctOption {
    for (final PracticeOption option in options) {
      if (option.isCorrect) {
        return option;
      }
    }
    return null;
  }
}
