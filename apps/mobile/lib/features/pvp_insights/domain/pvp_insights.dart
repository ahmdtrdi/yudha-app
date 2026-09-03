enum PvpInsightsWindow { sevenDays, thirtyDays, all }

extension PvpInsightsWindowValue on PvpInsightsWindow {
  String get apiValue => switch (this) {
    PvpInsightsWindow.sevenDays => '7d',
    PvpInsightsWindow.thirtyDays => '30d',
    PvpInsightsWindow.all => 'all',
  };

  String get label => switch (this) {
    PvpInsightsWindow.sevenDays => '7 hari',
    PvpInsightsWindow.thirtyDays => '30 hari',
    PvpInsightsWindow.all => 'Semua',
  };
}

enum PvpInsightsMode { all, ranked, casual }

extension PvpInsightsModeValue on PvpInsightsMode {
  String get apiValue => name;
  String get label => switch (this) {
    PvpInsightsMode.all => 'Semua',
    PvpInsightsMode.ranked => 'Ranked',
    PvpInsightsMode.casual => 'Casual',
  };
}

class PvpRecord {
  const PvpRecord({
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.attempts,
    required this.correct,
    required this.accuracy,
    required this.timeoutRate,
    required this.medianResponseTimeMs,
  });

  final int matches;
  final int wins;
  final int losses;
  final int draws;
  final double? winRate;
  final int attempts;
  final int correct;
  final double? accuracy;
  final double? timeoutRate;
  final int? medianResponseTimeMs;

  factory PvpRecord.fromJson(Map<String, dynamic>? json) {
    final answers = _map(json?['answers']);
    return PvpRecord(
      matches: _integer(json?['matches']),
      wins: _integer(json?['wins']),
      losses: _integer(json?['losses']),
      draws: _integer(json?['draws']),
      winRate: _nullableDouble(json?['winRate']),
      attempts: _integer(answers['attempts']),
      correct: _integer(answers['correct']),
      accuracy: _nullableDouble(answers['accuracy']),
      timeoutRate: _nullableDouble(answers['timeoutRate']),
      medianResponseTimeMs: _nullableInteger(answers['medianResponseTimeMs']),
    );
  }
}

class PvpTopicInsight {
  const PvpTopicInsight({
    required this.skillId,
    required this.label,
    required this.attempts,
    required this.accuracy,
    required this.timeoutRate,
    required this.evidenceStrength,
  });

  final String skillId;
  final String label;
  final int attempts;
  final double accuracy;
  final double timeoutRate;
  final String evidenceStrength;

  factory PvpTopicInsight.fromJson(Map<String, dynamic> json) =>
      PvpTopicInsight(
        skillId: json['skillId']?.toString() ?? '',
        label:
            json['subcategory']?.toString() ??
            json['category']?.toString() ??
            json['skillId']?.toString() ??
            'Topik',
        attempts: _integer(json['attempts']),
        accuracy: _nullableDouble(json['accuracy']) ?? 0,
        timeoutRate: _nullableDouble(json['timeoutRate']) ?? 0,
        evidenceStrength: json['evidenceStrength']?.toString() ?? 'low',
      );
}

class PvpTrendPoint {
  const PvpTrendPoint({required this.period, required this.accuracy});
  final String period;
  final double? accuracy;

  factory PvpTrendPoint.fromJson(Map<String, dynamic> json) => PvpTrendPoint(
    period: json['period']?.toString() ?? '',
    accuracy: _nullableDouble(_map(json['answers'])['accuracy']),
  );
}

class PvpCoach {
  const PvpCoach({
    required this.headline,
    required this.reason,
    required this.skillId,
    required this.category,
  });
  final String headline;
  final String reason;
  final String skillId;
  final String? category;

  factory PvpCoach.fromJson(Map<String, dynamic> json) => PvpCoach(
    headline: json['headline']?.toString() ?? 'Warm-up Solo',
    reason: json['reason']?.toString() ?? '',
    skillId: json['skillId']?.toString() ?? '',
    category: json['category']?.toString(),
  );
}

class PvpInsightsDashboard {
  const PvpInsightsDashboard({
    required this.target,
    required this.rating,
    required this.rank,
    required this.ratingStatus,
    required this.ratingChange,
    required this.publicPerformance,
    required this.privatePerformance,
    required this.topics,
    required this.trend,
    required this.broadAttempts,
    required this.enrichedAttempts,
    required this.coach,
  });

  final String target;
  final int rating;
  final int? rank;
  final String ratingStatus;
  final int ratingChange;
  final PvpRecord publicPerformance;
  final PvpRecord privatePerformance;
  final List<PvpTopicInsight> topics;
  final List<PvpTrendPoint> trend;
  final int broadAttempts;
  final int enrichedAttempts;
  final PvpCoach? coach;

  factory PvpInsightsDashboard.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']);
    final rating = _map(data['rating']);
    final coverage = _map(data['evidenceCoverage']);
    final coachJson = data['coach'];
    return PvpInsightsDashboard(
      target: data['target']?.toString() ?? 'cpns',
      rating: _integer(rating['value'], fallback: 1000),
      rank: _nullableInteger(rating['rank']),
      ratingStatus: rating['status']?.toString() ?? 'unrated',
      ratingChange: _integer(rating['changeInWindow']),
      publicPerformance: PvpRecord.fromJson(_map(data['publicPerformance'])),
      privatePerformance: PvpRecord.fromJson(_map(data['privatePerformance'])),
      topics: (data['topicBreakdown'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PvpTopicInsight.fromJson)
          .toList(growable: false),
      trend: (data['trend'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PvpTrendPoint.fromJson)
          .toList(growable: false),
      broadAttempts: _integer(coverage['broadAttemptCount']),
      enrichedAttempts: _integer(coverage['enrichedAttemptCount']),
      coach: coachJson is Map<String, dynamic>
          ? PvpCoach.fromJson(coachJson)
          : null,
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

int _integer(Object? value, {int fallback = 0}) =>
    _nullableInteger(value) ?? fallback;

int? _nullableInteger(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

double? _nullableDouble(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};
