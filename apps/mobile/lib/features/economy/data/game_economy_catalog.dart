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
  static const String defaultCharacterId = 'character-basic-squire';
  static const String defaultTowerId = 'tower-garda-biru';
  static const String defaultArenaId = 'arena-cpns';

  static const List<CosmeticItem> characters = <CosmeticItem>[
    CosmeticItem(
      id: defaultCharacterId,
      name: 'Squire',
      description: 'Ksatria pemula yang tangguh dan selalu siap berlatih.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.common,
      price: 0,
      assetPath: 'assets/game/basic_squire_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/basic_squire_idle.png',
        ready: 'assets/game/basic_squire_ready.png',
        attack: 'assets/game/basic_squire_attack.png',
        hit: 'assets/game/basic_squire_hit.png',
        projectiles: <String>[
          'assets/game/basic_squire_proj1.png',
          'assets/game/basic_squire_proj2.png',
          'assets/game/basic_squire_proj3.png',
        ],
      ),
    ),
    CosmeticItem(
      id: 'character-basic-pip',
      name: 'Pip',
      description: 'Pemanah lincah dengan serangan alam yang presisi.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.common,
      price: 500,
      assetPath: 'assets/game/basic_pip_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/basic_pip_idle.png',
        ready: 'assets/game/basic_pip_ready.png',
        attack: 'assets/game/basic_pip_attack.png',
        hit: 'assets/game/basic_pip_hit.png',
        projectiles: <String>[
          'assets/game/basic_pip_proj1.png',
          'assets/game/basic_pip_proj2.png',
          'assets/game/basic_pip_proj3.png',
        ],
      ),
    ),
    CosmeticItem(
      id: 'character-rare-ignis',
      name: 'Ignis',
      description: 'Penyihir api gesit dengan rentetan bara yang membara.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.rare,
      price: 900,
      assetPath: 'assets/game/rare_ignis_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/rare_ignis_idle.png',
        ready: 'assets/game/rare_ignis_ready.png',
        attack: 'assets/game/rare_ignis_attack.png',
        hit: 'assets/game/rare_ignis_hit.png',
        projectiles: <String>[
          'assets/game/rare_ignis_proj1.png',
          'assets/game/rare_ignis_proj2.png',
          'assets/game/rare_ignis_proj3.png',
        ],
      ),
    ),
    CosmeticItem(
      id: 'character-rare-brock',
      name: 'Brock',
      description: 'Golem batu perkasa yang menghantam dengan tenaga magma.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.rare,
      price: 1100,
      assetPath: 'assets/game/rare_brock_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/rare_brock_idle.png',
        ready: 'assets/game/rare_brock_ready.png',
        attack: 'assets/game/rare_brock_attack.png',
        hit: 'assets/game/rare_brock_hit.png',
        projectiles: <String>[
          'assets/game/rare_brock_proj1.png',
          'assets/game/rare_brock_proj2.png',
          'assets/game/rare_brock_proj3.png',
        ],
      ),
    ),
    CosmeticItem(
      id: 'character-legend-drakor',
      name: 'Drakor',
      description: 'Ksatria naga legendaris dengan kobaran api merah.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.legendary,
      price: 2200,
      assetPath: 'assets/game/legend_drakor_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/legend_drakor_idle.png',
        ready: 'assets/game/legend_drakor_ready.png',
        attack: 'assets/game/legend_drakor_attack.png',
        hit: 'assets/game/legend_drakor_hit.png',
        projectiles: <String>[
          'assets/game/legend_drakor_proj1.png',
          'assets/game/legend_drakor_proj2.png',
          'assets/game/legend_drakor_proj3.png',
        ],
      ),
    ),
    CosmeticItem(
      id: 'character-legend-luna',
      name: 'Luna',
      description: 'Penyihir bintang legendaris dengan kekuatan galaksi.',
      type: CosmeticType.character,
      rarity: CosmeticRarity.legendary,
      price: 2500,
      assetPath: 'assets/game/legend_luna_idle.png',
      characterVisuals: CharacterVisualAssets(
        idle: 'assets/game/legend_luna_idle.png',
        ready: 'assets/game/legend_luna_ready.png',
        attack: 'assets/game/legend_luna_attack.png',
        hit: 'assets/game/legend_luna_hit.png',
        projectiles: <String>[
          'assets/game/legend_luna_proj1.png',
          'assets/game/legend_luna_proj2.png',
          'assets/game/legend_luna_proj3.png',
        ],
      ),
    ),
  ];

  static const List<CosmeticItem> towers = <CosmeticItem>[
    CosmeticItem(
      id: defaultTowerId,
      name: 'Garda Biru',
      description: 'Benteng batu klasik dengan panji biru.',
      type: CosmeticType.tower,
      rarity: CosmeticRarity.common,
      price: 0,
      assetPath: 'assets/game/arena_tower_blue.png',
      battleAssetPath: 'assets/game/arena_turret_blue.png',
    ),
    CosmeticItem(
      id: 'tower-benteng-bara',
      name: 'Benteng Bara',
      description: 'Menara coral hangat dengan ukiran emas.',
      type: CosmeticType.tower,
      rarity: CosmeticRarity.rare,
      price: 650,
      assetPath: 'assets/game/arena_tower_coral.png',
      battleAssetPath: 'assets/game/arena_turret_coral.png',
    ),
  ];

  static const List<CosmeticItem> arenas = <CosmeticItem>[
    CosmeticItem(
      id: defaultArenaId,
      name: 'Arena CPNS',
      description: 'Uji wawasan kebangsaan, numerik, verbal, dan logika.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.common,
      price: 0,
      assetPath: 'assets/game/arena_cpns.png',
    ),
    CosmeticItem(
      id: 'arena-bumn',
      name: 'Arena BUMN',
      description: 'Soal AKHLAK, verbal, numerik, dan logika kerja.',
      type: CosmeticType.arena,
      rarity: CosmeticRarity.common,
      price: 0,
      assetPath: 'assets/game/arena_bumn.png',
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
      id: 'premium-300-tower',
      pointsRequired: 300,
      track: PassTrack.premium,
      label: 'Benteng Bara',
      cosmeticItemId: 'tower-benteng-bara',
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
      label: 'Pip',
      cosmeticItemId: 'character-basic-pip',
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
    ...towers,
  ];

  static CosmeticItem? findCosmetic(String itemId) {
    for (final CosmeticItem item in cosmetics) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  static CosmeticItem? findCharacter(String itemId) {
    for (final CosmeticItem item in characters) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  static CosmeticItem? findTower(String itemId) {
    for (final CosmeticItem item in towers) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  static CosmeticItem? findArena(String itemId) {
    for (final CosmeticItem item in arenas) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }
}
