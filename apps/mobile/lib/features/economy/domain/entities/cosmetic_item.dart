enum CosmeticType { character, arena }

enum CosmeticRarity { common, rare, epic, legendary }

class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
    required this.price,
    this.assetPath,
    this.passExclusive = false,
  });

  final String id;
  final String name;
  final String description;
  final CosmeticType type;
  final CosmeticRarity rarity;
  final int price;
  final String? assetPath;
  final bool passExclusive;
}
