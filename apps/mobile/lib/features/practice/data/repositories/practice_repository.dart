import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_history_batch.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';

abstract class PracticeRepository {
  Future<PracticeDashboard> fetchDashboard();

  Future<PracticeHistoryBatch> fetchHistory({
    required int limit,
    required int offset,
  });

  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  });

  Future<PracticeSession> startRecommendedSession({
    required String category,
    String? subcategory,
    required String recommendationId,
  }) {
    return startSession(category: category, subcategory: subcategory);
  }

  Future<String> requestHint({
    required String sessionId,
    required String sessionQuestionId,
  }) {
    throw UnsupportedError('Server-tracked hints are not implemented.');
  }

  Future<PracticeAnswerResult> submitAnswer({
    required String sessionId,
    required String sessionQuestionId,
    required int selectedOptionIndex,
    required int responseTimeMs,
    required bool usedHint,
  });

  Future<PracticeSessionSummary> finishSession({required String sessionId});
}
