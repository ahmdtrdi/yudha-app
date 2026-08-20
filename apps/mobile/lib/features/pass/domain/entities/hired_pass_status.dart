class HiredPassStatus {
  const HiredPassStatus({
    required this.seasonId,
    required this.passPoints,
    required this.premiumActive,
    required this.adFree,
    required this.expiresAt,
    required this.missions,
    required this.rewards,
    required this.claimedRewardIds,
  });

  final String? seasonId;
  final int passPoints;
  final bool premiumActive;
  final bool adFree;
  final DateTime? expiresAt;
  final List<HiredPassMission> missions;
  final List<HiredPassReward> rewards;
  final Set<String> claimedRewardIds;
}

class HiredPassReward {
  const HiredPassReward({
    required this.id,
    required this.track,
    required this.pointsRequired,
    required this.label,
    required this.coins,
    this.itemId,
  });

  final String id;
  final String track;
  final int pointsRequired;
  final String label;
  final int coins;
  final String? itemId;
}

class HiredPassMission {
  const HiredPassMission({
    required this.id,
    required this.title,
    required this.description,
    required this.cadence,
    required this.progress,
    required this.target,
    required this.passPointsReward,
    required this.completed,
  });

  final String id;
  final String title;
  final String description;
  final String cadence;
  final int progress;
  final int target;
  final int passPointsReward;
  final bool completed;
}
