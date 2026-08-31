enum CosmeticType { character, tower, arena }

enum CosmeticRarity { common, rare, epic, legendary }

class CharacterVisualAssets {
  const CharacterVisualAssets({
    required this.idle,
    required this.ready,
    required this.attack,
    required this.hit,
    required this.projectiles,
  });

  final String idle;
  final String ready;
  final String attack;
  final String hit;
  final List<String> projectiles;

  Iterable<String> get all => <String>[
    idle,
    ready,
    attack,
    hit,
    ...projectiles,
  ];

  String projectileForLevel(int level) {
    return projectiles[(level.clamp(1, projectiles.length) - 1)];
  }
}

class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
    required this.price,
    this.assetPath,
    this.battleAssetPath,
    this.destroyedAssetPath,
    this.characterVisuals,
    this.passExclusive = false,
  });

  final String id;
  final String name;
  final String description;
  final CosmeticType type;
  final CosmeticRarity rarity;
  final int price;
  final String? assetPath;
  final String? battleAssetPath;
  final String? destroyedAssetPath;
  final CharacterVisualAssets? characterVisuals;
  final bool passExclusive;
}
