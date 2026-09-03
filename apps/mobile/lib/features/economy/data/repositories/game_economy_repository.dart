import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

class AuthoritativeEconomySnapshot {
  const AuthoritativeEconomySnapshot({
    required this.coins,
    required this.energy,
    required this.maxEnergy,
    required this.dailyRefillTarget,
    this.nextRefillAt,
    required this.isPro,
    this.proExpiresAt,
    required this.ownedItemIds,
    required this.characterId,
    required this.towerId,
    required this.arenaId,
    required this.items,
  });

  final int coins;
  final int energy;
  final int maxEnergy;
  final int dailyRefillTarget;
  final DateTime? nextRefillAt;
  final bool isPro;
  final DateTime? proExpiresAt;
  final Set<String> ownedItemIds;
  final String characterId;
  final String towerId;
  final String arenaId;
  final List<CosmeticItem> items;
}

abstract class GameEconomyRepository {
  const GameEconomyRepository();

  Future<AuthoritativeEconomySnapshot> fetch();

  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(CosmeticItem item);

  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  });

  Future<AuthoritativeEconomySnapshot> grantBetaCredit({int coins = 100});

  Future<AuthoritativeEconomySnapshot> purchaseEnergyPack(String packageId);

  void dispose() {}
}
