import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.target,
    this.rankPoints,
    this.tier,
    this.rankedStats,
    this.yCoins,
    this.characterId,
    this.towerId,
    this.streak,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString().trim() ?? '',
      fullName:
          (json['fullName'] ?? json['full_name'])?.toString().trim() ?? '',
      target: _targetFromValue(json['target']),
      rankPoints: _nullableInt(json['rankPoints'] ?? json['rank_points']),
      tier: _nullableText(json['tier']),
      rankedStats: json['rankedStats'] is Map
          ? ProfileRankedStats.fromJson(
              Map<String, dynamic>.from(json['rankedStats'] as Map),
            )
          : null,
      yCoins: _nullableInt(json['yCoins'] ?? json['y_coins']),
      characterId: _nullableText(json['characterId'] ?? json['character_id']),
      towerId: _nullableText(json['towerId'] ?? json['tower_id']),
      streak: json['streak'] is Map
          ? ProfileStreak.fromJson(
              Map<String, dynamic>.from(json['streak'] as Map),
            )
          : null,
    );
  }

  final String id;
  final String username;
  final String fullName;
  final ProfileTarget target;
  final int? rankPoints;
  final String? tier;
  final ProfileRankedStats? rankedStats;
  final int? yCoins;
  final String? characterId;
  final String? towerId;
  final ProfileStreak? streak;

  String get displayName {
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (username.isNotEmpty) {
      return username;
    }
    return 'Kamu';
  }

  static ProfileTarget _targetFromValue(Object? value) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == ProfileTarget.bumn.name
        ? ProfileTarget.bumn
        : ProfileTarget.cpns;
  }

  static int? _nullableInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _nullableText(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class ProfileRankedStats {
  const ProfileRankedStats({
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
  });

  factory ProfileRankedStats.fromJson(Map<String, dynamic> json) {
    return ProfileRankedStats(
      wins: UserProfile._nullableInt(json['wins']) ?? 0,
      losses: UserProfile._nullableInt(json['losses']) ?? 0,
      draws: UserProfile._nullableInt(json['draws']) ?? 0,
      winRate: _rate(json['winRate'] ?? json['win_rate']),
    );
  }

  final int wins;
  final int losses;
  final int draws;
  final double winRate;

  int get totalMatches => wins + losses + draws;

  static double _rate(Object? value) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return (parsed > 1 ? parsed / 100 : parsed).clamp(0, 1).toDouble();
  }
}

class ProfileStreak {
  const ProfileStreak({
    required this.current,
    required this.best,
    this.lastDate,
  });

  factory ProfileStreak.fromJson(Map<String, dynamic> json) {
    return ProfileStreak(
      current: UserProfile._nullableInt(json['current']) ?? 0,
      best: UserProfile._nullableInt(json['best']) ?? 0,
      lastDate: DateTime.tryParse(json['lastDate']?.toString() ?? ''),
    );
  }

  final int current;
  final int best;
  final DateTime? lastDate;
}
