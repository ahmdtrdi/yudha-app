import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

enum EconomySyncStatus { loading, synced, syncUnavailable }

enum EconomyDataSource { bundled, cache, server }

class GameEconomyState {
  const GameEconomyState({
    required this.yCoins,
    required this.ownedItemIds,
    required this.equippedCharacterId,
    required this.equippedTowerId,
    required this.equippedArenaId,
    required this.items,
    required this.syncStatus,
    required this.dataSource,
    this.syncErrorMessage,
  });

  factory GameEconomyState.initial() {
    return GameEconomyState(
      yCoins: 0,
      ownedItemIds: const <String>{
        GameEconomyCatalog.defaultCharacterId,
        GameEconomyCatalog.defaultTowerId,
        'arena-lembah-bara',
        GameEconomyCatalog.defaultArenaId,
        'arena-gurun-cendekia',
        'arena-rimba-yudha',
      },
      equippedCharacterId: GameEconomyCatalog.defaultCharacterId,
      equippedTowerId: GameEconomyCatalog.defaultTowerId,
      equippedArenaId: GameEconomyCatalog.defaultArenaId,
      items: GameEconomyCatalog.cosmetics,
      syncStatus: EconomySyncStatus.loading,
      dataSource: EconomyDataSource.bundled,
    );
  }

  final int yCoins;
  final Set<String> ownedItemIds;
  final String equippedCharacterId;
  final String equippedTowerId;
  final String equippedArenaId;
  final List<CosmeticItem> items;
  final EconomySyncStatus syncStatus;
  final EconomyDataSource dataSource;
  final String? syncErrorMessage;

  bool get isAuthoritative => syncStatus == EconomySyncStatus.synced;

  bool owns(String itemId) => ownedItemIds.contains(itemId);

  List<CosmeticItem> get characters => items
      .where((CosmeticItem item) => item.type == CosmeticType.character)
      .toList(growable: false);

  List<CosmeticItem> get towers => items
      .where((CosmeticItem item) => item.type == CosmeticType.tower)
      .toList(growable: false);

  GameEconomyState copyWith({
    int? yCoins,
    Set<String>? ownedItemIds,
    String? equippedCharacterId,
    String? equippedTowerId,
    String? equippedArenaId,
    List<CosmeticItem>? items,
    EconomySyncStatus? syncStatus,
    EconomyDataSource? dataSource,
    String? syncErrorMessage,
    bool clearSyncError = false,
  }) {
    return GameEconomyState(
      yCoins: yCoins ?? this.yCoins,
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      equippedCharacterId: equippedCharacterId ?? this.equippedCharacterId,
      equippedTowerId: equippedTowerId ?? this.equippedTowerId,
      equippedArenaId: equippedArenaId ?? this.equippedArenaId,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      dataSource: dataSource ?? this.dataSource,
      syncErrorMessage: clearSyncError
          ? null
          : syncErrorMessage ?? this.syncErrorMessage,
    );
  }
}
