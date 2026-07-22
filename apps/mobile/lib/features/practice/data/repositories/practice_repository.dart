import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';

abstract class PracticeRepository {
  Future<PracticeDashboard> fetchDashboard();

  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  });

  Future<PracticeAnswerResult> submitAnswer({
    required String sessionId,
    required String sessionQuestionId,
    required int selectedOptionIndex,
    required int responseTimeMs,
    required bool usedHint,
  });

  Future<PracticeSessionSummary> finishSession({required String sessionId});
}
