import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

abstract class InterviewRepository {
  Future<InterviewStartResult> startSession(InterviewLaunchConfig config);

  Future<List<InterviewSessionSummaryRecord>> listSessions();

  Future<InterviewSessionDetailRecord> getSession(String sessionId);

  Future<InterviewTurnResult> submitAnswer({
    required String sessionId,
    required String answer,
    required String idempotencyKey,
  });

  Future<InterviewFinalSummary> completeSession(String sessionId);
}

class InterviewStartResult {
  const InterviewStartResult({
    required this.sessionId,
    required this.status,
    required this.openingQuestion,
  });

  final String sessionId;
  final String status;
  final InterviewMessage openingQuestion;
}

class InterviewTurnResult {
  const InterviewTurnResult({
    required this.sessionId,
    required this.status,
    required this.nextQuestion,
    this.evaluation,
    this.finalSummary,
  });

  final String sessionId;
  final String status;
  final InterviewMessage? nextQuestion;
  final InterviewEvaluation? evaluation;
  final InterviewFinalSummary? finalSummary;
}
