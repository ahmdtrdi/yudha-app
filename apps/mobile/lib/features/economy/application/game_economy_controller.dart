import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

class EconomyActionResult {
  const EconomyActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class GameEconomyController extends StateNotifier<GameEconomyState> {
  GameEconomyController({GameEconomyStorage? storage})
    : _storage = storage,
      super(GameEconomyState.initial()) {
    unawaited(_loadSavedState());
  }

  final GameEconomyStorage? _storage;
  bool _hasLocalMutation = false;

  Future<void> _loadSavedState() async {
    final GameEconomyState? saved = await _storage?.load();
    if (saved == null || _hasLocalMutation) {
      return;
    }
    state = saved;
  }

  EconomyActionResult purchase(CosmeticItem item) {
    if (state.owns(item.id)) {
      return equip(item);
    }
    if (item.passExclusive) {
      return const EconomyActionResult(
        success: false,
        message: 'Item ini hanya tersedia dari Hired Pass.',
      );
    }
    if (state.yCoins < item.price) {
      return const EconomyActionResult(
        success: false,
        message: 'Y-Coin belum cukup. Tambah saldo lalu coba lagi.',
      );
    }

    final Set<String> owned = <String>{...state.ownedItemIds, item.id};
    _setState(
      state.copyWith(
        yCoins: state.yCoins - item.price,
        ownedItemIds: owned,
        equippedCharacterId: item.type == CosmeticType.character
            ? item.id
            : state.equippedCharacterId,
        equippedArenaId: item.type == CosmeticType.arena
            ? item.id
            : state.equippedArenaId,
      ),
    );
    return EconomyActionResult(
      success: true,
      message: '${item.name} dibeli dan langsung dipakai.',
    );
  }

  EconomyActionResult equip(CosmeticItem item) {
    if (!state.owns(item.id)) {
      return const EconomyActionResult(
        success: false,
        message: 'Beli atau klaim item ini terlebih dahulu.',
      );
    }

    final bool alreadyEquipped = switch (item.type) {
      CosmeticType.character => state.equippedCharacterId == item.id,
      CosmeticType.arena => state.equippedArenaId == item.id,
    };
    if (alreadyEquipped) {
      return EconomyActionResult(
        success: true,
        message: '${item.name} sedang dipakai.',
      );
    }

    _setState(
      state.copyWith(
        equippedCharacterId: item.type == CosmeticType.character
            ? item.id
            : state.equippedCharacterId,
        equippedArenaId: item.type == CosmeticType.arena
            ? item.id
            : state.equippedArenaId,
      ),
    );
    return EconomyActionResult(
      success: true,
      message: '${item.name} siap dipakai di PvP.',
    );
  }

  EconomyActionResult topUp(YCoinTopUpPackage package) {
    final int updatedCoins = (state.yCoins + package.totalCoins).clamp(
      0,
      999999999,
    );
    _setState(state.copyWith(yCoins: updatedCoins));
    final String prefix = package.isBetaCredit
        ? 'Beta credit'
        : 'Simulasi top-up';
    return EconomyActionResult(
      success: true,
      message: '$prefix +${package.totalCoins} Y-Coin berhasil.',
    );
  }

  EconomyActionResult activatePremiumPassForBeta() {
    if (state.premiumPassActive) {
      return const EconomyActionResult(
        success: true,
        message: 'Hired Pass Premium sudah aktif.',
      );
    }
    _setState(state.copyWith(premiumPassActive: true));
    return const EconomyActionResult(
      success: true,
      message: 'Hired Pass Premium aktif untuk beta testing.',
    );
  }

  EconomyActionResult claimPassReward(PassReward reward) {
    if (state.hasClaimed(reward.id)) {
      return const EconomyActionResult(
        success: false,
        message: 'Reward ini sudah diklaim.',
      );
    }
    if (state.passPoints < reward.pointsRequired) {
      return EconomyActionResult(
        success: false,
        message: 'Butuh ${reward.pointsRequired} Pass Points.',
      );
    }
    if (reward.track == PassTrack.premium && !state.premiumPassActive) {
      return const EconomyActionResult(
        success: false,
        message: 'Aktifkan Hired Pass Premium untuk klaim reward ini.',
      );
    }

    final Set<String> owned = <String>{...state.ownedItemIds};
    final String? cosmeticItemId = reward.cosmeticItemId;
    if (cosmeticItemId != null) {
      owned.add(cosmeticItemId);
    }
    final Set<String> claimed = <String>{...state.claimedRewardIds, reward.id};
    _setState(
      state.copyWith(
        yCoins: (state.yCoins + reward.yCoins).clamp(0, 999999999),
        ownedItemIds: owned,
        claimedRewardIds: claimed,
      ),
    );
    return EconomyActionResult(
      success: true,
      message: '${reward.label} berhasil diklaim.',
    );
  }

  void addPassPointsForTesting([int amount = 100]) {
    if (amount <= 0) {
      return;
    }
    _setState(
      state.copyWith(passPoints: (state.passPoints + amount).clamp(0, 999999)),
    );
  }

  void _setState(GameEconomyState nextState) {
    _hasLocalMutation = true;
    state = nextState;
    final GameEconomyStorage? storage = _storage;
    if (storage != null) {
      unawaited(storage.save(nextState));
    }
  }
}
