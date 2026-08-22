import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

class AuthoritativeEconomySnapshot {
  const AuthoritativeEconomySnapshot({
    required this.coins,
    required this.ownedItemIds,
    required this.characterId,
    required this.towerId,
    required this.arenaId,
    required this.items,
  });

  final int coins;
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

  void dispose() {}
}
