import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';

class GameEconomyState {
  const GameEconomyState({
    required this.yCoins,
    required this.ownedItemIds,
    required this.equippedCharacterId,
    required this.equippedArenaId,
    required this.passPoints,
    required this.premiumPassActive,
    required this.claimedRewardIds,
  });

  factory GameEconomyState.initial() {
    return const GameEconomyState(
      yCoins: 300,
      ownedItemIds: <String>{
        GameEconomyCatalog.defaultCharacterId,
        GameEconomyCatalog.defaultArenaId,
      },
      equippedCharacterId: GameEconomyCatalog.defaultCharacterId,
      equippedArenaId: GameEconomyCatalog.defaultArenaId,
      passPoints: 340,
      premiumPassActive: false,
      claimedRewardIds: <String>{},
    );
  }

  final int yCoins;
  final Set<String> ownedItemIds;
  final String equippedCharacterId;
  final String equippedArenaId;
  final int passPoints;
  final bool premiumPassActive;
  final Set<String> claimedRewardIds;

  bool owns(String itemId) => ownedItemIds.contains(itemId);

  bool hasClaimed(String rewardId) => claimedRewardIds.contains(rewardId);

  GameEconomyState copyWith({
    int? yCoins,
    Set<String>? ownedItemIds,
    String? equippedCharacterId,
    String? equippedArenaId,
    int? passPoints,
    bool? premiumPassActive,
    Set<String>? claimedRewardIds,
  }) {
    return GameEconomyState(
      yCoins: yCoins ?? this.yCoins,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      equippedCharacterId: equippedCharacterId ?? this.equippedCharacterId,
      equippedArenaId: equippedArenaId ?? this.equippedArenaId,
      passPoints: passPoints ?? this.passPoints,
      premiumPassActive: premiumPassActive ?? this.premiumPassActive,
      claimedRewardIds: claimedRewardIds ?? this.claimedRewardIds,
    );
  }
}
