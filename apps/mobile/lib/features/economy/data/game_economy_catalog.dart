import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

class YCoinTopUpPackage {
  const YCoinTopUpPackage({
    required this.id,
    required this.coins,
    required this.priceLabel,
    this.bonusCoins = 0,
    this.isBetaCredit = false,
  });

  final String id;
  final int coins;
  final int bonusCoins;
  final String priceLabel;
  final bool isBetaCredit;

  int get totalCoins => coins + bonusCoins;
}

enum PassTrack { free, premium }

class PassReward {
  const PassReward({
    required this.id,
    required this.pointsRequired,
    required this.track,
    required this.label,
    this.yCoins = 0,
    this.cosmeticItemId,
  });

  final String id;
  final int pointsRequired;
  final PassTrack track;
  final String label;
  final int yCoins;
  final String? cosmeticItemId;
}

abstract final class GameEconomyCatalog {
  static const String defaultCharacterId = 'character-cadet-blue';
  static const String defaultArenaId = 'arena-training-garden';

  static const List<CosmeticItem> characters = <CosmeticItem>[
    CosmeticItem(
      id: defaultCharacterId,
      name: 'Cadet Biru',
      description: 'Seragam klasik para pejuang YUDHA.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.common,
      price: 0,
      assetPath: 'assets/game/arena_hero_blue.png',
    ),
    CosmeticItem(
      id: 'character-violet-striker',
      name: 'Violet Striker',
      description: 'Cadet cepat dengan armor violet dan navy.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.epic,
      price: 850,
      assetPath: 'assets/game/arena_hero_violet.png',
    ),
    CosmeticItem(
      id: 'character-teal-strategist',
      name: 'Teal Strategist',
      description: 'Ahli strategi eksklusif Hired Pass.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.legendary,
      price: 0,
      assetPath: 'assets/game/arena_hero_teal.png',
      passExclusive: true,
    ),
  ];

  static const List<CosmeticItem> arenas = <CosmeticItem>[
    CosmeticItem(
      id: defaultArenaId,
      name: 'Training Garden',
      description: 'Arena hijau klasik untuk mengasah kemampuan.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.common,
      price: 0,
    ),
    CosmeticItem(
      id: 'arena-sunset-canyon',
      name: 'Sunset Canyon',
      description: 'Lembah hangat dengan sungai biru yang tenang.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.rare,
      price: 600,
    ),
    CosmeticItem(
      id: 'arena-midnight-circuit',
      name: 'Midnight Circuit',
      description: 'Arena malam futuristis dengan jalur cyan.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.epic,
      price: 950,
    ),
    CosmeticItem(
      id: 'arena-aurora-summit',
      name: 'Aurora Summit',
      description: 'Puncak aurora eksklusif Hired Pass.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.legendary,
      price: 0,
      passExclusive: true,
    ),
  ];

  static const List<YCoinTopUpPackage> topUpPackages = <YCoinTopUpPackage>[
    YCoinTopUpPackage(
      id: 'beta-100',
      coins: 100,
      priceLabel: 'GRATIS',
      isBetaCredit: true,
    ),
    YCoinTopUpPackage(id: 'pack-500', coins: 500, priceLabel: 'Rp9.000'),
    YCoinTopUpPackage(
      id: 'pack-1200',
      coins: 1100,
      bonusCoins: 100,
      priceLabel: 'Rp19.000',
    ),
    YCoinTopUpPackage(
      id: 'pack-2800',
      coins: 2500,
      bonusCoins: 300,
      priceLabel: 'Rp39.000',
    ),
    YCoinTopUpPackage(
      id: 'pack-6800',
      coins: 6000,
      bonusCoins: 800,
      priceLabel: 'Rp89.000',
    ),
  ];

  static const List<PassReward> passRewards = <PassReward>[
    PassReward(
      id: 'free-100-coins',
      pointsRequired: 100,
      track: PassTrack.free,
      label: '100 Y-Coin',
      yCoins: 100,
    ),
    PassReward(
      id: 'premium-100-coins',
      pointsRequired: 100,
      track: PassTrack.premium,
      label: '250 Y-Coin',
      yCoins: 250,
    ),
    PassReward(
      id: 'free-300-coins',
      pointsRequired: 300,
      track: PassTrack.free,
      label: '150 Y-Coin',
      yCoins: 150,
    ),
    PassReward(
      id: 'premium-300-arena',
      pointsRequired: 300,
      track: PassTrack.premium,
      label: 'Aurora Summit',
      cosmeticItemId: 'arena-aurora-summit',
    ),
    PassReward(
      id: 'free-600-coins',
      pointsRequired: 600,
      track: PassTrack.free,
      label: '300 Y-Coin',
      yCoins: 300,
    ),
    PassReward(
      id: 'premium-600-character',
      pointsRequired: 600,
      track: PassTrack.premium,
      label: 'Teal Strategist',
      cosmeticItemId: 'character-teal-strategist',
    ),
    PassReward(
      id: 'free-1000-coins',
      pointsRequired: 1000,
      track: PassTrack.free,
      label: '500 Y-Coin',
      yCoins: 500,
    ),
    PassReward(
      id: 'premium-1000-coins',
      pointsRequired: 1000,
      track: PassTrack.premium,
      label: '1.000 Y-Coin',
      yCoins: 1000,
    ),
  ];

  static List<CosmeticItem> get cosmetics => <CosmeticItem>[
    ...characters,
    ...arenas,
  ];

  static CosmeticItem? findCosmetic(String itemId) {
    for (final CosmeticItem item in cosmetics) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }
}
