import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

abstract class PracticeRepository {
  Future<List<PracticeTopic>> fetchTopics();

  Future<List<PracticeQuestion>> fetchQuestions({required String topicId});

  Future<PracticeQuestion> fetchQuestionOfDay();
}
