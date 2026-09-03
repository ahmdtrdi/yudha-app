class LearningDashboard {
  const LearningDashboard({
    required this.asOf,
    required this.calculationVersion,
    required this.target,
    required this.nextAction,
    required this.coverage,
    required this.accuracy,
    required this.pace,
    required this.skillStates,
    required this.trends,
    required this.retention,
    required this.assessment,
    required this.activity,
    required this.competition,
  });

  factory LearningDashboard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary = _map(json['summary']);
    return LearningDashboard(
      asOf: DateTime.tryParse(json['asOf']?.toString() ?? ''),
      calculationVersion: json['calculationVersion']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      nextAction: LearningRecommendation.tryFrom(json['nextAction']),
      coverage: LearningCoverage.fromJson(_map(summary['curriculumCoverage'])),
      accuracy: LearningMetric.fromJson(
        _map(summary['unseenIndependentAccuracy']),
      ),
      pace: LearningPace.fromJson(_map(summary['pace'])),
      skillStates: _listOfMaps(
        json['skillStates'],
      ).map(LearningSkillState.fromJson).toList(growable: false),
      trends: _listOfMaps(
        json['trends'],
      ).map(LearningTrend.fromJson).toList(growable: false),
      retention: _listOfMaps(
        json['retention'],
      ).map(LearningRetention.fromJson).toList(growable: false),
      assessment: LearningAssessment.fromJson(_map(json['assessment'])),
      activity: LearningActivity.fromJson(_map(json['activity'])),
      competition: LearningCompetition.fromJson(_map(json['competition'])),
    );
  }

  final DateTime? asOf;
  final String calculationVersion;
  final String target;
  final LearningRecommendation? nextAction;
  final LearningCoverage coverage;
  final LearningMetric accuracy;
  final LearningPace pace;
  final List<LearningSkillState> skillStates;
  final List<LearningTrend> trends;
  final List<LearningRetention> retention;
  final LearningAssessment assessment;
  final LearningActivity activity;
  final LearningCompetition competition;
}

class LearningRecommendation {
  const LearningRecommendation({
    required this.id,
    required this.target,
    required this.objective,
    required this.skillId,
    required this.skillLabel,
    required this.category,
    required this.subcategory,
    required this.mechanicMode,
    required this.reasonHeadline,
    required this.reasonDescription,
    required this.confidence,
    required this.expiresAt,
    required this.runnable,
    required this.unavailableReason,
    required this.compatibilityAdapter,
    required this.compatibilityLabel,
  });

  factory LearningRecommendation.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> skill = _map(json['skill']);
    final Map<String, dynamic> reason = _map(json['reason']);
    final Map<String, dynamic> availability = _map(json['availability']);
    return LearningRecommendation(
      id: json['recommendationId']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      skillId: skill['id']?.toString() ?? '',
      skillLabel: skill['label']?.toString() ?? '',
      category: _nullableText(skill['category']),
      subcategory: _nullableText(skill['subcategory']),
      mechanicMode: json['mechanicMode']?.toString() ?? 'standard',
      reasonHeadline: reason['headline']?.toString() ?? '',
      reasonDescription: reason['description']?.toString() ?? '',
      confidence: json['confidence']?.toString() ?? 'low',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      runnable: availability['runnable'] == true,
      unavailableReason: _nullableText(availability['reason']),
      compatibilityAdapter: _nullableText(availability['compatibilityAdapter']),
      compatibilityLabel: _nullableText(availability['label']),
    );
  }

  static LearningRecommendation? tryFrom(Object? value) {
    if (value is! Map) return null;
    final LearningRecommendation result = LearningRecommendation.fromJson(
      Map<String, dynamic>.from(value),
    );
    return result.id.isEmpty ? null : result;
  }

  final String id;
  final String target;
  final String objective;
  final String skillId;
  final String skillLabel;
  final String? category;
  final String? subcategory;
  final String mechanicMode;
  final String reasonHeadline;
  final String reasonDescription;
  final String confidence;
  final DateTime? expiresAt;
  final bool runnable;
  final String? unavailableReason;
  final String? compatibilityAdapter;
  final String? compatibilityLabel;

  String get objectiveLabel => switch (objective) {
    'repair_accuracy' => 'Perbaiki akurasi',
    'spaced_review' => 'Ulangi materi',
    'collect_evidence' => 'Kumpulkan bukti',
    'build_fluency' => 'Bangun kelancaran',
    'maintain_coverage' => 'Jaga cakupan',
    _ => 'Langkah berikutnya',
  };
}

class LearningMetric {
  const LearningMetric({
    required this.value,
    required this.correctCount,
    required this.attemptCount,
    required this.uniqueQuestionCount,
    required this.confidence,
    required this.asOf,
  });

  factory LearningMetric.fromJson(Map<String, dynamic> json) {
    return LearningMetric(
      value: _nullableDouble(json['value']),
      correctCount: _int(json['correctCount']),
      attemptCount: _int(json['attemptCount']),
      uniqueQuestionCount: _int(json['uniqueQuestionCount']),
      confidence: json['confidence']?.toString() ?? 'low',
      asOf: DateTime.tryParse(json['asOf']?.toString() ?? ''),
    );
  }

  final double? value;
  final int correctCount;
  final int attemptCount;
  final int uniqueQuestionCount;
  final String confidence;
  final DateTime? asOf;
}

class LearningCoverage {
  const LearningCoverage({
    required this.value,
    required this.coveredSkillCount,
    required this.requiredSkillCount,
    required this.confidence,
  });

  factory LearningCoverage.fromJson(Map<String, dynamic> json) {
    return LearningCoverage(
      value: _nullableDouble(json['value']),
      coveredSkillCount: _int(json['coveredSkillCount']),
      requiredSkillCount: _int(json['requiredSkillCount']),
      confidence: json['confidence']?.toString() ?? 'low',
    );
  }

  final double? value;
  final int coveredSkillCount;
  final int requiredSkillCount;
  final String confidence;
}

class LearningPace {
  const LearningPace({
    required this.value,
    required this.baselineType,
    required this.attemptCount,
    required this.confidence,
  });

  factory LearningPace.fromJson(Map<String, dynamic> json) {
    return LearningPace(
      value: _nullableDouble(json['value']),
      baselineType: _nullableText(json['baselineType']),
      attemptCount: _int(json['attemptCount']),
      confidence: json['confidence']?.toString() ?? 'low',
    );
  }

  final double? value;
  final String? baselineType;
  final int attemptCount;
  final String confidence;
}

class LearningSkillState {
  const LearningSkillState({
    required this.skillId,
    required this.label,
    required this.category,
    required this.subcategory,
    required this.requiredSkill,
    required this.status,
    required this.confidence,
    required this.accuracy,
    required this.assistedAccuracy,
    required this.smoothedAccuracy,
    required this.hintRate,
    required this.medianResponseTimeMs,
    required this.paceRatio,
    required this.paceBaselineType,
    required this.paceAttemptCount,
    required this.timeoutRate,
    required this.trendPercentagePoints,
    required this.coverageSufficient,
    required this.recommendedMechanic,
    required this.lastPracticedAt,
  });

  factory LearningSkillState.fromJson(Map<String, dynamic> json) {
    return LearningSkillState(
      skillId: json['skillId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      category: _nullableText(json['category']),
      subcategory: _nullableText(json['subcategory']),
      requiredSkill: json['required'] == true,
      status: json['status']?.toString() ?? 'collecting_data',
      confidence: json['evidenceConfidence']?.toString() ?? 'low',
      accuracy: LearningMetric.fromJson(
        _map(json['unseenIndependentAccuracy']),
      ),
      assistedAccuracy: LearningMetric.fromJson(_map(json['assistedAccuracy'])),
      smoothedAccuracy: _nullableDouble(json['smoothedAccuracy']),
      hintRate: _nullableDouble(json['hintRate']),
      medianResponseTimeMs: _nullableInt(json['medianResponseTimeMs']),
      paceRatio: _nullableDouble(json['paceRatio']),
      paceBaselineType: _nullableText(json['paceBaselineType']),
      paceAttemptCount: _int(json['paceAttemptCount']),
      timeoutRate: _nullableDouble(json['timeoutRate']),
      trendPercentagePoints: _nullableDouble(json['trendPercentagePoints']),
      coverageSufficient: json['coverageSufficient'] == true,
      recommendedMechanic:
          json['recommendedMechanic']?.toString() ?? 'standard',
      lastPracticedAt: DateTime.tryParse(
        json['lastPracticedAt']?.toString() ?? '',
      ),
    );
  }

  final String skillId;
  final String label;
  final String? category;
  final String? subcategory;
  final bool requiredSkill;
  final String status;
  final String confidence;
  final LearningMetric accuracy;
  final LearningMetric assistedAccuracy;
  final double? smoothedAccuracy;
  final double? hintRate;
  final int? medianResponseTimeMs;
  final double? paceRatio;
  final String? paceBaselineType;
  final int paceAttemptCount;
  final double? timeoutRate;
  final double? trendPercentagePoints;
  final bool coverageSufficient;
  final String recommendedMechanic;
  final DateTime? lastPracticedAt;
}

class LearningTrend {
  const LearningTrend({
    required this.skillId,
    required this.label,
    required this.valuePercentagePoints,
  });

  factory LearningTrend.fromJson(Map<String, dynamic> json) => LearningTrend(
    skillId: json['skillId']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    valuePercentagePoints: _nullableDouble(json['valuePercentagePoints']),
  );

  final String skillId;
  final String label;
  final double? valuePercentagePoints;
}

class LearningRetention {
  const LearningRetention({
    required this.skillId,
    required this.label,
    required this.status,
    required this.reviewDueAt,
    required this.accuracy,
    required this.correctCount,
    required this.attemptCount,
    required this.confidence,
    required this.asOf,
  });

  factory LearningRetention.fromJson(Map<String, dynamic> json) {
    return LearningRetention(
      skillId: json['skillId']?.toString() ?? '',
      label: json['label']?.toString() ?? json['skillId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'scheduled',
      reviewDueAt: DateTime.tryParse(json['reviewDueAt']?.toString() ?? ''),
      accuracy: _nullableDouble(json['accuracy']),
      correctCount: _int(json['correctCount']),
      attemptCount: _int(json['attemptCount']),
      confidence: json['confidence']?.toString() ?? 'low',
      asOf: DateTime.tryParse(json['asOf']?.toString() ?? ''),
    );
  }

  final String skillId;
  final String label;
  final String status;
  final DateTime? reviewDueAt;
  final double? accuracy;
  final int correctCount;
  final int attemptCount;
  final String confidence;
  final DateTime? asOf;
}

class LearningAssessment {
  const LearningAssessment({
    required this.status,
    required this.score,
    required this.correctCount,
    required this.attemptCount,
    required this.occurredAt,
    required this.confidence,
    required this.asOf,
    required this.baseline,
    required this.latest,
    required this.improvementPercentagePoints,
    required this.categoryBreakdown,
    required this.skillBreakdown,
  });

  factory LearningAssessment.fromJson(Map<String, dynamic> json) {
    return LearningAssessment(
      status: json['status']?.toString() ?? 'not_available',
      score: _nullableDouble(json['score']),
      correctCount: _nullableInt(json['correctCount']),
      attemptCount: _nullableInt(json['attemptCount']),
      occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? ''),
      confidence: json['confidence']?.toString() ?? 'low',
      asOf: DateTime.tryParse(json['asOf']?.toString() ?? ''),
      baseline: LearningAssessmentPoint.tryFrom(json['baseline']),
      latest: LearningAssessmentPoint.tryFrom(json['latest']),
      improvementPercentagePoints: _nullableDouble(
        json['improvementPercentagePoints'],
      ),
      categoryBreakdown: _listOfMaps(
        json['categoryBreakdown'],
      ).map(LearningBreakdown.fromJson).toList(growable: false),
      skillBreakdown: _listOfMaps(
        json['skillBreakdown'],
      ).map(LearningBreakdown.fromJson).toList(growable: false),
    );
  }

  final String status;
  final double? score;
  final int? correctCount;
  final int? attemptCount;
  final DateTime? occurredAt;
  final String confidence;
  final DateTime? asOf;
  final LearningAssessmentPoint? baseline;
  final LearningAssessmentPoint? latest;
  final double? improvementPercentagePoints;
  final List<LearningBreakdown> categoryBreakdown;
  final List<LearningBreakdown> skillBreakdown;
}

class LearningAssessmentPoint {
  const LearningAssessmentPoint({
    required this.score,
    required this.correctCount,
    required this.attemptCount,
    required this.occurredAt,
    required this.blueprintVersion,
  });

  factory LearningAssessmentPoint.fromJson(Map<String, dynamic> json) =>
      LearningAssessmentPoint(
        score: _nullableDouble(json['score']),
        correctCount: _nullableInt(json['correctCount']),
        attemptCount: _nullableInt(json['attemptCount']),
        occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? ''),
        blueprintVersion: _nullableText(json['blueprintVersion']),
      );

  static LearningAssessmentPoint? tryFrom(Object? value) => value is Map
      ? LearningAssessmentPoint.fromJson(Map<String, dynamic>.from(value))
      : null;

  final double? score;
  final int? correctCount;
  final int? attemptCount;
  final DateTime? occurredAt;
  final String? blueprintVersion;
}

class LearningBreakdown {
  const LearningBreakdown({
    required this.id,
    required this.label,
    required this.value,
    required this.correctCount,
    required this.attemptCount,
    required this.confidence,
    required this.asOf,
  });

  factory LearningBreakdown.fromJson(Map<String, dynamic> json) {
    final String id =
        json['skillId']?.toString() ?? json['category']?.toString() ?? '';
    return LearningBreakdown(
      id: id,
      label: json['label']?.toString() ?? id,
      value: _nullableDouble(
        json['score'] ?? json['accuracy'] ?? json['value'],
      ),
      correctCount: _nullableInt(json['correctCount']),
      attemptCount: _nullableInt(json['attemptCount']),
      confidence: json['confidence']?.toString() ?? 'low',
      asOf: DateTime.tryParse(json['asOf']?.toString() ?? ''),
    );
  }

  final String id;
  final String label;
  final double? value;
  final int? correctCount;
  final int? attemptCount;
  final String confidence;
  final DateTime? asOf;
}

class LearningActivity {
  const LearningActivity({
    required this.activeLearningDays,
    required this.questionsAnswered,
    required this.activeLearningMinutes,
    required this.sessionCount,
    required this.streak,
    required this.dailyHistory,
    required this.weeklyActivity,
    required this.recentSessions,
  });

  factory LearningActivity.fromJson(Map<String, dynamic> json) {
    return LearningActivity(
      activeLearningDays: _int(json['activeLearningDays']),
      questionsAnswered: _int(json['questionsAnswered']),
      activeLearningMinutes: _nullableDouble(json['activeLearningMinutes']),
      sessionCount: _int(json['sessionCount']),
      streak: LearningStreak.fromJson(_map(json['streak'])),
      dailyHistory: _listOfMaps(
        json['dailyHistory'],
      ).map(LearningActivityDay.fromJson).toList(growable: false),
      weeklyActivity: _listOfMaps(
        json['weeklyActivity'],
      ).map(LearningActivityWeek.fromJson).toList(growable: false),
      recentSessions: _listOfMaps(
        json['recentSessions'],
      ).map(LearningRecentSession.fromJson).toList(growable: false),
    );
  }

  final int activeLearningDays;
  final int questionsAnswered;
  final double? activeLearningMinutes;
  final int sessionCount;
  final LearningStreak streak;
  final List<LearningActivityDay> dailyHistory;
  final List<LearningActivityWeek> weeklyActivity;
  final List<LearningRecentSession> recentSessions;
}

class LearningStreak {
  const LearningStreak({
    required this.current,
    required this.best,
    this.lastDate,
  });

  factory LearningStreak.fromJson(Map<String, dynamic> json) => LearningStreak(
    current: _int(json['current']),
    best: _int(json['best']),
    lastDate: DateTime.tryParse(json['lastDate']?.toString() ?? ''),
  );

  final int current;
  final int best;
  final DateTime? lastDate;
}

class LearningActivityDay {
  const LearningActivityDay({
    required this.date,
    required this.questionsAnswered,
    required this.sessionCount,
    required this.activeLearningMinutes,
  });

  factory LearningActivityDay.fromJson(Map<String, dynamic> json) =>
      LearningActivityDay(
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
        questionsAnswered: _int(json['questionsAnswered']),
        sessionCount: _int(json['sessionCount']),
        activeLearningMinutes: _nullableDouble(json['activeLearningMinutes']),
      );

  final DateTime? date;
  final int questionsAnswered;
  final int sessionCount;
  final double? activeLearningMinutes;
}

class LearningActivityWeek {
  const LearningActivityWeek({
    required this.startsOn,
    required this.endsOn,
    required this.questionsAnswered,
    required this.sessionCount,
    required this.activeLearningMinutes,
  });

  factory LearningActivityWeek.fromJson(Map<String, dynamic> json) =>
      LearningActivityWeek(
        startsOn: DateTime.tryParse(json['startsOn']?.toString() ?? ''),
        endsOn: DateTime.tryParse(json['endsOn']?.toString() ?? ''),
        questionsAnswered: _int(json['questionsAnswered']),
        sessionCount: _int(json['sessionCount']),
        activeLearningMinutes: _nullableDouble(json['activeLearningMinutes']),
      );

  final DateTime? startsOn;
  final DateTime? endsOn;
  final int questionsAnswered;
  final int sessionCount;
  final double? activeLearningMinutes;
}

class LearningRecentSession {
  const LearningRecentSession({
    required this.sessionKey,
    required this.lastActivityAt,
    required this.completionState,
    required this.objective,
    required this.mechanicMode,
    required this.skillLabels,
    required this.correctCount,
    required this.attemptCount,
    required this.accuracy,
  });

  factory LearningRecentSession.fromJson(Map<String, dynamic> json) =>
      LearningRecentSession(
        sessionKey: json['sessionKey']?.toString() ?? '',
        lastActivityAt: DateTime.tryParse(
          json['lastActivityAt']?.toString() ?? '',
        ),
        completionState: json['completionState']?.toString() ?? 'in_progress',
        objective: _nullableText(json['objective']),
        mechanicMode: _nullableText(json['mechanicMode']),
        skillLabels: json['skillLabels'] is List
            ? List<String>.unmodifiable(
                (json['skillLabels'] as List).map((value) => value.toString()),
              )
            : const <String>[],
        correctCount: _int(json['correctCount']),
        attemptCount: _int(json['attemptCount']),
        accuracy: _nullableDouble(json['accuracy']),
      );

  final String sessionKey;
  final DateTime? lastActivityAt;
  final String completionState;
  final String? objective;
  final String? mechanicMode;
  final List<String> skillLabels;
  final int correctCount;
  final int attemptCount;
  final double? accuracy;
}

class LearningCompetition {
  const LearningCompetition({
    required this.separateEvidenceContext,
    required this.accuracy,
    required this.rankPoints,
    required this.tier,
    required this.matchRecord,
    required this.soloComparison,
  });

  factory LearningCompetition.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> accuracy = _map(json['accuracy']);
    return LearningCompetition(
      separateEvidenceContext: json['separateEvidenceContext'] == true,
      accuracy: LearningMetric(
        value: _nullableDouble(accuracy['value']),
        correctCount: _int(accuracy['correctCount']),
        attemptCount: _int(accuracy['attemptCount']),
        uniqueQuestionCount: 0,
        confidence: accuracy['confidence']?.toString() ?? 'low',
        asOf: DateTime.tryParse(accuracy['asOf']?.toString() ?? ''),
      ),
      rankPoints: _int(json['rankPoints']),
      tier: json['tier']?.toString() ?? 'rookie',
      matchRecord: LearningMatchRecord.fromJson(_map(json['matchRecord'])),
      soloComparison: LearningContextComparison.tryFrom(json['soloComparison']),
    );
  }

  final bool separateEvidenceContext;
  final LearningMetric accuracy;
  final int rankPoints;
  final String tier;
  final LearningMatchRecord matchRecord;
  final LearningContextComparison? soloComparison;
}

class LearningMatchRecord {
  const LearningMatchRecord({
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalMatches,
    required this.winRate,
  });

  factory LearningMatchRecord.fromJson(Map<String, dynamic> json) =>
      LearningMatchRecord(
        wins: _int(json['wins']),
        losses: _int(json['losses']),
        draws: _int(json['draws']),
        totalMatches: _int(json['totalMatches']),
        winRate: _nullableDouble(json['winRate']),
      );

  final int wins;
  final int losses;
  final int draws;
  final int totalMatches;
  final double? winRate;
}

class LearningContextComparison {
  const LearningContextComparison({required this.gapPercentagePoints});

  factory LearningContextComparison.fromJson(Map<String, dynamic> json) =>
      LearningContextComparison(
        gapPercentagePoints: _nullableDouble(json['gapPercentagePoints']),
      );

  static LearningContextComparison? tryFrom(Object? value) => value is Map
      ? LearningContextComparison.fromJson(Map<String, dynamic>.from(value))
      : null;

  final double? gapPercentagePoints;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _listOfMaps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];

String? _nullableText(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

int _int(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
