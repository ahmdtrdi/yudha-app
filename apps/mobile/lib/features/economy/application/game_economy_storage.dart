import 'package:shared_preferences/shared_preferences.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

abstract class GameEconomyStorage {
  Future<GameEconomyState?> load();

  Future<void> save(GameEconomyState state);

  Future<void> clear();
}

class SharedPreferencesGameEconomyStorage implements GameEconomyStorage {
  const SharedPreferencesGameEconomyStorage();

  static const String _coinsKey = 'economy.yCoins';
  static const String _ownedItemsKey = 'economy.ownedItems';
  static const String _equippedCharacterKey = 'economy.equippedCharacter';
  static const String _equippedTowerKey = 'economy.equippedTower';
  static const String _equippedArenaKey = 'economy.equippedArena';

  @override
  Future<GameEconomyState?> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey(_coinsKey) &&
        !preferences.containsKey(_ownedItemsKey)) {
      return null;
    }

    final GameEconomyState fallback = GameEconomyState.initial();
    final Set<String> owned = <String>{
      ...fallback.ownedItemIds,
      ...preferences.getStringList(_ownedItemsKey) ?? <String>[],
    };
    final String savedCharacter =
        preferences.getString(_equippedCharacterKey) ??
        fallback.equippedCharacterId;
    final String savedArena =
        preferences.getString(_equippedArenaKey) ?? fallback.equippedArenaId;
    final String savedTower =
        preferences.getString(_equippedTowerKey) ?? fallback.equippedTowerId;

    return GameEconomyState(
      yCoins: (preferences.getInt(_coinsKey) ?? fallback.yCoins).clamp(
        0,
        999999999,
      ),
      ownedItemIds: owned,
      equippedCharacterId:
          owned.contains(savedCharacter) &&
              GameEconomyCatalog.findCharacter(savedCharacter) != null
          ? savedCharacter
          : GameEconomyCatalog.defaultCharacterId,
      equippedTowerId:
          owned.contains(savedTower) &&
              GameEconomyCatalog.findTower(savedTower) != null
          ? savedTower
          : GameEconomyCatalog.defaultTowerId,
      equippedArenaId: GameEconomyCatalog.findArena(savedArena) != null
          ? savedArena
          : GameEconomyCatalog.defaultArenaId,
      items: GameEconomyCatalog.cosmetics,
      syncStatus: EconomySyncStatus.loading,
      dataSource: EconomyDataSource.cache,
    );
  }

  @override
  Future<void> save(GameEconomyState state) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_coinsKey, state.yCoins);
    await preferences.setStringList(
      _ownedItemsKey,
      state.ownedItemIds.toList()..sort(),
    );
    await preferences.setString(
      _equippedCharacterKey,
      state.equippedCharacterId,
    );
    await preferences.setString(_equippedTowerKey, state.equippedTowerId);
    await preferences.setString(_equippedArenaKey, state.equippedArenaId);
  }

  @override
  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.remove(_coinsKey),
      preferences.remove(_ownedItemsKey),
      preferences.remove(_equippedCharacterKey),
      preferences.remove(_equippedTowerKey),
      preferences.remove(_equippedArenaKey),
    ]);
  }
}
