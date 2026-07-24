class HiredPassStatus {
  const HiredPassStatus({required this.passPoints, required this.missions});

  final int passPoints;
  final List<HiredPassMission> missions;
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
