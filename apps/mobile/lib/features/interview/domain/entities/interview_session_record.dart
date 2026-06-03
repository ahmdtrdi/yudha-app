import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

class InterviewSessionSummaryRecord {
  const InterviewSessionSummaryRecord({
    required this.sessionId,
    required this.status,
    required this.companyId,
    required this.targetRole,
    required this.mode,
    required this.language,
    required this.responseStyle,
    required this.createdAt,
    required this.updatedAt,
    this.finalSummary,
  });

  final String sessionId;
  final String status;
  final String companyId;
  final String targetRole;
  final String mode;
  final String language;
  final String responseStyle;
  final InterviewFinalSummary? finalSummary;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InterviewSessionDetailRecord {
  const InterviewSessionDetailRecord({
    required this.sessionId,
    required this.status,
    required this.companyId,
    required this.targetRole,
    required this.mode,
    required this.responseStyle,
    required this.messages,
    this.finalSummary,
  });

  final String sessionId;
  final String status;
  final String companyId;
  final String targetRole;
  final String mode;
  final String responseStyle;
  final List<InterviewMessage> messages;
  final InterviewFinalSummary? finalSummary;
}
