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
    this.dimensions = const InterviewDimensions(),
    this.candidateFacts = const <String>[],
    this.coachNote,
    this.suggestedRewrite,
  });

  factory InterviewEvaluation.fromJson(Map<String, dynamic> json) {
    return InterviewEvaluation(
      overallScore: _readDouble(json['overallScore']),
      dimensions: InterviewDimensions.fromJson(json['dimensions']),
      candidateFacts: _readStringList(json['candidateFacts']),
      strengths: _readStringList(json['strengths']),
      improvements: _readStringList(json['improvements']),
      coachNote: json['coachNote'] as String?,
      suggestedRewrite: json['suggestedRewrite'] as String?,
    );
  }

  final double overallScore;
  final InterviewDimensions dimensions;
  final List<String> candidateFacts;
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

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class InterviewFinalSummary {
  const InterviewFinalSummary({
    required this.overallScore,
    required this.strengths,
    required this.improvements,
    required this.answerCount,
    this.dimensions = const InterviewDimensions(),
  });

  factory InterviewFinalSummary.fromJson(Map<String, dynamic> json) {
    return InterviewFinalSummary(
      overallScore: InterviewEvaluation._readDouble(json['overallScore']),
      dimensions: InterviewDimensions.fromJson(json['dimensions']),
      strengths: InterviewEvaluation._readStringList(json['strengths']),
      improvements: InterviewEvaluation._readStringList(json['improvements']),
      answerCount: (json['answerCount'] as num?)?.toInt() ?? 0,
    );
  }

  final double overallScore;
  final InterviewDimensions dimensions;
  final List<String> strengths;
  final List<String> improvements;
  final int answerCount;
}

class InterviewDimensions {
  const InterviewDimensions({
    this.relevance = 0,
    this.clarity = 0,
    this.structure = 0,
    this.confidence = 0,
    this.impact = 0,
    this.authenticity = 0,
  });

  factory InterviewDimensions.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const InterviewDimensions();
    }
    return InterviewDimensions(
      relevance: InterviewEvaluation._readDouble(value['relevance']),
      clarity: InterviewEvaluation._readDouble(value['clarity']),
      structure: InterviewEvaluation._readDouble(value['structure']),
      confidence: InterviewEvaluation._readDouble(value['confidence']),
      impact: InterviewEvaluation._readDouble(value['impact']),
      authenticity: InterviewEvaluation._readDouble(value['authenticity']),
    );
  }

  final double relevance;
  final double clarity;
  final double structure;
  final double confidence;
  final double impact;
  final double authenticity;

  bool get hasScores =>
      relevance > 0 ||
      clarity > 0 ||
      structure > 0 ||
      confidence > 0 ||
      impact > 0 ||
      authenticity > 0;
}
