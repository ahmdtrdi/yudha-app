class BetaWelcomeReward {
  const BetaWelcomeReward({
    required this.id,
    required this.coinAmount,
    required this.energyAmount,
    this.acknowledgedAt,
  });

  factory BetaWelcomeReward.fromJson(Map<String, dynamic> json) =>
      BetaWelcomeReward(
        id: json['id'] as String,
        coinAmount: (json['coinAmount'] as num).toInt(),
        energyAmount: (json['energyAmount'] as num).toInt(),
        acknowledgedAt: json['acknowledgedAt'] as String?,
      );

  final String id;
  final int coinAmount;
  final int energyAmount;
  final String? acknowledgedAt;
}
