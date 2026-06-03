import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

abstract class PracticeRepository {
  Future<PracticeDashboard> fetchDashboard({required ProfileTarget target});

  Future<List<PracticeQuestion>> fetchQuestions({required String topicId});
}
