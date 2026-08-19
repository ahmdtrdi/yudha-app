class PerformanceAnalytics {
  const PerformanceAnalytics({required this.practice, required this.battle});

  factory PerformanceAnalytics.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> publicMatches = _readMap(json['publicMatches']);
    return PerformanceAnalytics(
      practice: PracticePerformance.fromJson(_readMap(json['practice'])),
      battle: BattlePerformance.fromJson(
        publicMatches.isEmpty ? _readMap(json['battle']) : publicMatches,
      ),
    );
  }

  final PracticePerformance practice;
  final BattlePerformance battle;

  bool get hasAnyActivity =>
      practice.totalAnswered > 0 || battle.totalMatches > 0;
}

class PracticePerformance {
  const PracticePerformance({
    required this.overallAccuracy,
    required this.totalAnswered,
    required this.categoryBreakdown,
    required this.weakSubcategories,
    required this.averageResponseTimeMs,
  });

  factory PracticePerformance.fromJson(Map<String, dynamic> json) {
    return PracticePerformance(
      overallAccuracy: _readDouble(json['overallAccuracy'] ?? json['accuracy']),
      totalAnswered: _readInt(json['totalAnswered'] ?? json['sampleSize']),
      categoryBreakdown: _readMaps(
        json['categoryBreakdown'],
      ).map(CategoryPerformance.fromJson).toList(growable: false),
      weakSubcategories: _readMaps(
        json['weakSubcategories'] ?? json['subcategoryBreakdown'],
      ).map(SubcategoryPerformance.fromJson).toList(growable: false),
      averageResponseTimeMs: _readInt(
        json['avgResponseTimeMs'] ?? json['averageResponseTimeMs'],
      ),
    );
  }

  final double overallAccuracy;
  final int totalAnswered;
  final List<CategoryPerformance> categoryBreakdown;
  final List<SubcategoryPerformance> weakSubcategories;
  final int averageResponseTimeMs;
}

class BattlePerformance {
  const BattlePerformance({
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.totalMatches,
  });

  factory BattlePerformance.fromJson(Map<String, dynamic> json) {
    return BattlePerformance(
      winRate: _readRate(json['winrate'] ?? json['winRate']),
      wins: _readInt(json['wins']),
      losses: _readInt(json['losses']),
      totalMatches: _readInt(json['totalMatches'] ?? json['sampleSize']),
    );
  }

  final double winRate;
  final int wins;
  final int losses;
  final int totalMatches;
}

class CategoryPerformance {
  const CategoryPerformance({
    required this.category,
    required this.accuracy,
    required this.totalAnswered,
  });

  factory CategoryPerformance.fromJson(Map<String, dynamic> json) {
    return CategoryPerformance(
      category: json['category']?.toString() ?? '',
      accuracy: _readDouble(json['accuracy']),
      totalAnswered: _readInt(json['totalAnswered'] ?? json['sampleSize']),
    );
  }

  final String category;
  final double accuracy;
  final int totalAnswered;
}

class SubcategoryPerformance {
  const SubcategoryPerformance({
    required this.subcategory,
    required this.accuracy,
    required this.totalAnswered,
  });

  factory SubcategoryPerformance.fromJson(Map<String, dynamic> json) {
    return SubcategoryPerformance(
      subcategory: json['subcategory']?.toString() ?? '',
      accuracy: _readDouble(json['accuracy']),
      totalAnswered: _readInt(json['totalAnswered'] ?? json['sampleSize']),
    );
  }

  final String subcategory;
  final double accuracy;
  final int totalAnswered;
}

Map<String, dynamic> _readMap(Object? value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

Iterable<Map<String, dynamic>> _readMaps(Object? value) {
  return value is List<dynamic>
      ? value.whereType<Map<String, dynamic>>()
      : const <Map<String, dynamic>>[];
}

double _readDouble(Object? value) {
  return value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}

double _readRate(Object? value) {
  final double rate = _readDouble(value);
  return rate > 1 ? rate / 100 : rate;
}

int _readInt(Object? value) {
  return value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
}
