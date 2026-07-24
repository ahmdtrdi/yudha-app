import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

class EconomyActionResult {
  const EconomyActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class GameEconomyController extends StateNotifier<GameEconomyState> {
  GameEconomyController({
    GameEconomyStorage? storage,
    GameEconomyRepository? repository,
  }) : _storage = storage,
       _repository = repository,
       super(GameEconomyState.initial()) {
    unawaited(_loadInitialState());
  }

  final GameEconomyStorage? _storage;
  final GameEconomyRepository? _repository;
  bool _hasLocalMutation = false;

  Future<void> _loadInitialState() async {
    final GameEconomyState? saved = await _storage?.load();
    if (saved != null && !_hasLocalMutation) {
      state = saved;
    }
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository.fetch();
      if (!_hasLocalMutation) {
        _applyAuthoritativeSnapshot(snapshot);
      }
    } catch (_) {
      // Keep the last local projection while the API is temporarily offline.
    }
  }

  Future<EconomyActionResult> purchaseAuthoritative(CosmeticItem item) async {
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return purchase(item);
    }
    if (item.type == CosmeticType.arena) {
      return const EconomyActionResult(
        success: false,
        message: 'Arena tidak dijual. Pilih arena langsung dari menu PvP.',
      );
    }
    if (state.owns(item.id)) {
      return equipAuthoritative(item);
    }
    if (item.passExclusive) {
      return const EconomyActionResult(
        success: false,
        message: 'Item ini hanya tersedia dari Hired Pass.',
      );
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository
          .purchaseAndEquip(item);
      _applyAuthoritativeSnapshot(snapshot);
      return EconomyActionResult(
        success: true,
        message: '${item.name} dibeli dan langsung dipakai.',
      );
    } catch (error) {
      return EconomyActionResult(success: false, message: _economyError(error));
    }
  }

  Future<EconomyActionResult> equipAuthoritative(CosmeticItem item) async {
    if (item.type == CosmeticType.arena) {
      return selectArenaAuthoritative(item);
    }
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return equip(item);
    }
    if (!state.owns(item.id)) {
      return const EconomyActionResult(
        success: false,
        message: 'Beli atau klaim item ini terlebih dahulu.',
      );
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository.setLoadout(
        characterId: item.type == CosmeticType.character ? item.id : null,
        towerId: item.type == CosmeticType.tower ? item.id : null,
      );
      _applyAuthoritativeSnapshot(snapshot);
      return EconomyActionResult(
        success: true,
        message: '${item.name} siap dipakai di PvP.',
      );
    } catch (error) {
      return EconomyActionResult(success: false, message: _economyError(error));
    }
  }

  Future<EconomyActionResult> selectArenaAuthoritative(
    CosmeticItem arena,
  ) async {
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return selectArena(arena);
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository.setLoadout(
        arenaId: arena.id,
      );
      _applyAuthoritativeSnapshot(snapshot);
      return EconomyActionResult(
        success: true,
        message: '${arena.name} dipilih.',
      );
    } catch (error) {
      return EconomyActionResult(success: false, message: _economyError(error));
    }
  }

  Future<EconomyActionResult> syncAuthoritativeLoadout() async {
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return const EconomyActionResult(
        success: true,
        message: 'Loadout lokal siap.',
      );
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository.setLoadout(
        characterId: state.equippedCharacterId,
        towerId: state.equippedTowerId,
        arenaId: state.equippedArenaId,
      );
      _applyAuthoritativeSnapshot(snapshot);
      return const EconomyActionResult(
        success: true,
        message: 'Loadout tersinkron.',
      );
    } catch (error) {
      return EconomyActionResult(success: false, message: _economyError(error));
    }
  }

  Future<EconomyActionResult> topUpAuthoritative(
    YCoinTopUpPackage package,
  ) async {
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      return topUp(package);
    }
    if (!package.isBetaCredit) {
      return const EconomyActionResult(
        success: false,
        message: 'Pembayaran paket Y-Coin belum tersedia di versi beta.',
      );
    }
    try {
      final AuthoritativeEconomySnapshot snapshot = await repository
          .grantBetaCredit();
      _applyAuthoritativeSnapshot(snapshot);
      return EconomyActionResult(
        success: true,
        message: 'Beta credit +${package.totalCoins} Y-Coin berhasil.',
      );
    } catch (error) {
      return EconomyActionResult(success: false, message: _economyError(error));
    }
  }

  EconomyActionResult purchase(CosmeticItem item) {
    if (item.type == CosmeticType.arena) {
      return const EconomyActionResult(
        success: false,
        message: 'Arena tidak dijual. Pilih arena langsung dari menu PvP.',
      );
    }
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
        equippedTowerId: item.type == CosmeticType.tower
            ? item.id
            : state.equippedTowerId,
      ),
    );
    return EconomyActionResult(
      success: true,
      message: '${item.name} dibeli dan langsung dipakai.',
    );
  }

  EconomyActionResult equip(CosmeticItem item) {
    if (item.type == CosmeticType.arena) {
      return selectArena(item);
    }
    if (!state.owns(item.id)) {
      return const EconomyActionResult(
        success: false,
        message: 'Beli atau klaim item ini terlebih dahulu.',
      );
    }

    final bool alreadyEquipped = switch (item.type) {
      CosmeticType.character => state.equippedCharacterId == item.id,
      CosmeticType.tower => state.equippedTowerId == item.id,
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
        equippedTowerId: item.type == CosmeticType.tower
            ? item.id
            : state.equippedTowerId,
      ),
    );
    return EconomyActionResult(
      success: true,
      message: '${item.name} siap dipakai di PvP.',
    );
  }

  EconomyActionResult selectArena(CosmeticItem arena) {
    if (arena.type != CosmeticType.arena ||
        GameEconomyCatalog.findArena(arena.id) == null) {
      return const EconomyActionResult(
        success: false,
        message: 'Arena tidak tersedia.',
      );
    }
    if (state.equippedArenaId == arena.id) {
      return EconomyActionResult(
        success: true,
        message: '${arena.name} sudah dipilih.',
      );
    }
    _setState(state.copyWith(equippedArenaId: arena.id));
    return EconomyActionResult(
      success: true,
      message: '${arena.name} dipilih.',
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

  void applyBattleReward(int coinsDelta) {
    if (coinsDelta == 0) {
      return;
    }
    _setState(
      state.copyWith(yCoins: (state.yCoins + coinsDelta).clamp(0, 999999999)),
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

  void _applyAuthoritativeSnapshot(AuthoritativeEconomySnapshot snapshot) {
    _setState(
      state.copyWith(
        yCoins: snapshot.coins,
        ownedItemIds: snapshot.ownedItemIds,
        equippedCharacterId: snapshot.characterId,
        equippedTowerId: snapshot.towerId,
        equippedArenaId: snapshot.arenaId,
      ),
    );
  }

  String _economyError(Object error) {
    final String message = error.toString().replaceFirst('Exception: ', '');
    return message.trim().isEmpty
        ? 'Gagal menyinkronkan loadout. Coba lagi.'
        : message;
  }
}
