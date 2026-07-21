enum InterviewMessageAuthor { interviewer, candidate }

class InterviewMessage {
  const InterviewMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.evaluation,
    this.audioAvailable = false,
  });

  final String id;
  final InterviewMessageAuthor author;
  final String text;
  final DateTime createdAt;
  final InterviewEvaluation? evaluation;
  final bool audioAvailable;
}

class InterviewEvaluation {
  const InterviewEvaluation({
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    this.coachNote,
    this.suggestedRewrite,
  });

  factory InterviewEvaluation.fromJson(Map<String, dynamic> json) {
    return InterviewEvaluation(
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      strengths: _readStringList(json['strengths']),
      improvements: _readStringList(json['improvements']),
      coachNote: json['coachNote'] as String?,
      suggestedRewrite: json['suggestedRewrite'] as String?,
    );
  }

  final double overallScore;
  final List<String> strengths;
  final List<String> improvements;
  final String? coachNote;
  final String? suggestedRewrite;

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}

class InterviewFinalSummary {
  const InterviewFinalSummary({
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.answerCount,
  });

  factory InterviewFinalSummary.fromJson(Map<String, dynamic> json) {
    return InterviewFinalSummary(
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      strengths: InterviewEvaluation._readStringList(json['strengths']),
      improvements: InterviewEvaluation._readStringList(json['improvements']),
      answerCount: (json['answerCount'] as num?)?.toInt() ?? 0,
    );
  }

  final double overallScore;
  final List<String> strengths;
  final List<String> improvements;
  final int answerCount;
}
