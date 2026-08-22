import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/errors/user_facing_error.dart';
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
  Future<void>? _refreshInFlight;

  Future<void> _loadInitialState() async {
    if (_repository == null) {
      await clearSession();
      return;
    }
    final GameEconomyState? cached = await _storage?.load();
    if (cached != null && state.syncStatus != EconomySyncStatus.synced) {
      state = cached.copyWith(
        syncStatus: EconomySyncStatus.loading,
        dataSource: EconomyDataSource.cache,
        clearSyncError: true,
      );
    }
    await refresh();
  }

  Future<void> clearSession() async {
    state = GameEconomyState.initial().copyWith(
      syncStatus: EconomySyncStatus.syncUnavailable,
      syncErrorMessage: 'Silakan masuk untuk menyinkronkan ekonomi.',
    );
    await _storage?.clear();
  }

  Future<void> refresh() {
    final Future<void>? existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final Future<void> operation = _refresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _refresh() async {
    final GameEconomyRepository? repository = _repository;
    if (repository == null) {
      _markUnavailable('Silakan masuk untuk menyinkronkan ekonomi.');
      return;
    }
    state = state.copyWith(
      syncStatus: EconomySyncStatus.loading,
      clearSyncError: true,
    );
    try {
      _applyAuthoritativeSnapshot(await repository.fetch());
    } catch (error) {
      _markUnavailable(_economyError(error, syncing: true));
    }
  }

  Future<EconomyActionResult> purchaseAuthoritative(CosmeticItem item) async {
    final EconomyActionResult? unavailable = _mutationUnavailable();
    if (unavailable != null) return unavailable;
    if (item.type == CosmeticType.arena) {
      return const EconomyActionResult(
        success: false,
        message: 'Arena tidak dijual. Arena mengikuti target belajar.',
      );
    }
    if (state.owns(item.id)) return equipAuthoritative(item);
    if (item.passExclusive) {
      return const EconomyActionResult(
        success: false,
        message: 'Item ini hanya tersedia dari Hired Pass.',
      );
    }
    return _runMutation(
      () => _repository!.purchaseAndEquip(item),
      successMessage: '${item.name} dibeli dan langsung dipakai.',
    );
  }

  Future<EconomyActionResult> equipAuthoritative(CosmeticItem item) async {
    if (item.type == CosmeticType.arena) {
      return selectArenaAuthoritative(item);
    }
    final EconomyActionResult? unavailable = _mutationUnavailable();
    if (unavailable != null) return unavailable;
    if (!state.owns(item.id)) {
      return const EconomyActionResult(
        success: false,
        message: 'Beli atau klaim item ini terlebih dahulu.',
      );
    }
    return _runMutation(
      () => _repository!.setLoadout(
        characterId: item.type == CosmeticType.character ? item.id : null,
        towerId: item.type == CosmeticType.tower ? item.id : null,
      ),
      successMessage: '${item.name} siap dipakai di PvP.',
    );
  }

  Future<EconomyActionResult> selectArenaAuthoritative(
    CosmeticItem arena,
  ) async {
    final EconomyActionResult? unavailable = _mutationUnavailable();
    if (unavailable != null) return unavailable;
    if (arena.type != CosmeticType.arena) {
      return const EconomyActionResult(
        success: false,
        message: 'Arena tidak tersedia.',
      );
    }
    return _runMutation(
      () => _repository!.setLoadout(arenaId: arena.id),
      successMessage: '${arena.name} dipilih.',
    );
  }

  Future<EconomyActionResult> syncAuthoritativeLoadout() async {
    final EconomyActionResult? unavailable = _mutationUnavailable();
    if (unavailable != null) return unavailable;
    return _runMutation(
      () => _repository!.setLoadout(
        characterId: state.equippedCharacterId,
        towerId: state.equippedTowerId,
        arenaId: state.equippedArenaId,
      ),
      successMessage: 'Loadout tersinkron.',
    );
  }

  Future<EconomyActionResult> topUpAuthoritative(
    YCoinTopUpPackage package,
  ) async {
    final EconomyActionResult? unavailable = _mutationUnavailable();
    if (unavailable != null) return unavailable;
    return _runMutation(
      () => _repository!.grantBetaCredit(coins: package.totalCoins),
      successMessage:
          'Beta credit +${package.totalCoins} Y-Coin berhasil (${package.priceLabel}).',
    );
  }

  Future<EconomyActionResult> _runMutation(
    Future<AuthoritativeEconomySnapshot> Function() mutation, {
    required String successMessage,
  }) async {
    try {
      _applyAuthoritativeSnapshot(await mutation());
      return EconomyActionResult(success: true, message: successMessage);
    } catch (error) {
      await refresh();
      return EconomyActionResult(
        success: false,
        message: state.syncStatus == EconomySyncStatus.syncUnavailable
            ? state.syncErrorMessage ?? _economyError(error)
            : _economyError(error),
      );
    }
  }

  EconomyActionResult? _mutationUnavailable() {
    if (_repository == null) {
      return const EconomyActionResult(
        success: false,
        message: 'Silakan masuk untuk melanjutkan.',
      );
    }
    if (!state.isAuthoritative) {
      return const EconomyActionResult(
        success: false,
        message:
            'Sinkronisasi ekonomi belum tersedia. Muat ulang lalu coba lagi.',
      );
    }
    return null;
  }

  void _applyAuthoritativeSnapshot(AuthoritativeEconomySnapshot snapshot) {
    state = state.copyWith(
      yCoins: snapshot.coins,
      ownedItemIds: snapshot.ownedItemIds,
      equippedCharacterId: snapshot.characterId,
      equippedTowerId: snapshot.towerId,
      equippedArenaId: snapshot.arenaId,
      items: snapshot.items,
      syncStatus: EconomySyncStatus.synced,
      dataSource: EconomyDataSource.server,
      clearSyncError: true,
    );
    final GameEconomyStorage? storage = _storage;
    if (storage != null) unawaited(storage.save(state));
  }

  void _markUnavailable(String message) {
    state = state.copyWith(
      syncStatus: EconomySyncStatus.syncUnavailable,
      syncErrorMessage: message,
    );
  }

  String _economyError(Object error, {bool syncing = false}) {
    return UserFacingError.describe(
      error,
      fallback: syncing
          ? 'Sinkronisasi ekonomi tidak tersedia. Coba muat ulang.'
          : 'Aksi ekonomi gagal. Coba lagi.',
      preserveDetails: true,
    );
  }
}
