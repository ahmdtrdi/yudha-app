import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';

void main() {
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
      (entry) => entry.id == 'premium-300-arena',
    );

    controller.activatePremiumPassForBeta();
    final EconomyActionResult result = controller.claimPassReward(reward);

    expect(result.success, isTrue);
    expect(controller.state.owns('arena-aurora-summit'), isTrue);
    expect(controller.state.hasClaimed(reward.id), isTrue);
  });
}
