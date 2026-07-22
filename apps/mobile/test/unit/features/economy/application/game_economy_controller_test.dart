import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

void main() {
  test('catalog exposes complete Basic, Rare, and Legend character sets', () {
    expect(
      GameEconomyCatalog.characters.map((character) => character.id),
      <String>[
        'character-basic-squire',
        'character-basic-pip',
        'character-rare-ignis',
        'character-rare-brock',
        'character-legend-drakor',
        'character-legend-luna',
      ],
    );
    expect(
      GameEconomyCatalog.characters.map((character) => character.rarity),
      <CosmeticRarity>[
        CosmeticRarity.common,
        CosmeticRarity.common,
        CosmeticRarity.rare,
        CosmeticRarity.rare,
        CosmeticRarity.legendary,
        CosmeticRarity.legendary,
      ],
    );
    for (final character in GameEconomyCatalog.characters) {
      expect(character.characterVisuals, isNotNull);
      expect(character.characterVisuals!.projectiles, hasLength(3));
      expect(character.characterVisuals!.all, hasLength(7));
    }
  });

  test('purchasing a cosmetic deducts Y-Coin, owns, and equips it', () {
    final GameEconomyController controller = GameEconomyController();
    final character = GameEconomyCatalog.characters[1];

    controller.topUp(GameEconomyCatalog.topUpPackages[2]);
    final int balanceBeforePurchase = controller.state.yCoins;

    final EconomyActionResult result = controller.purchase(character);

    expect(result.success, isTrue);
    expect(controller.state.yCoins, balanceBeforePurchase - character.price);
    expect(controller.state.owns(character.id), isTrue);
    expect(controller.state.equippedCharacterId, character.id);
  });

  test('purchase is rejected without enough Y-Coin', () {
    final GameEconomyController controller = GameEconomyController();
    final character = GameEconomyCatalog.characters[1];
    final int initialBalance = controller.state.yCoins;

    final EconomyActionResult result = controller.purchase(character);

    expect(result.success, isFalse);
    expect(controller.state.yCoins, initialBalance);
    expect(controller.state.owns(character.id), isFalse);
  });

  test(
    'tower can be purchased and equipped, while arena is free to select',
    () {
      final GameEconomyController controller = GameEconomyController();
      final tower = GameEconomyCatalog.towers[1];
      final arena = GameEconomyCatalog.arenas[1];

      controller.topUp(GameEconomyCatalog.topUpPackages[2]);
      final int balanceBeforeTower = controller.state.yCoins;

      final EconomyActionResult towerResult = controller.purchase(tower);
      final EconomyActionResult arenaResult = controller.selectArena(arena);

      expect(towerResult.success, isTrue);
      expect(controller.state.yCoins, balanceBeforeTower - tower.price);
      expect(controller.state.owns(tower.id), isTrue);
      expect(controller.state.equippedTowerId, tower.id);
      expect(arenaResult.success, isTrue);
      expect(controller.state.equippedArenaId, arena.id);
      expect(controller.state.owns(arena.id), isFalse);
    },
  );

  test('beta +100 can be used repeatedly', () {
    final GameEconomyController controller = GameEconomyController();
    final betaPackage = GameEconomyCatalog.topUpPackages.first;
    final int initialBalance = controller.state.yCoins;

    controller.topUp(betaPackage);
    controller.topUp(betaPackage);
    controller.topUp(betaPackage);

    expect(controller.state.yCoins, initialBalance + 300);
  });

  test('premium pass reward grants its permanent cosmetic', () {
    final GameEconomyController controller = GameEconomyController();
    final reward = GameEconomyCatalog.passRewards.firstWhere(
      (entry) => entry.id == 'premium-300-tower',
    );

    controller.activatePremiumPassForBeta();
    final EconomyActionResult result = controller.claimPassReward(reward);

    expect(result.success, isTrue);
    expect(controller.state.owns('tower-benteng-bara'), isTrue);
    expect(controller.state.hasClaimed(reward.id), isTrue);
  });
}
