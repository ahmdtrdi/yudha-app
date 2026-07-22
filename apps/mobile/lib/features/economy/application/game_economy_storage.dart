import 'package:shared_preferences/shared_preferences.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

abstract class GameEconomyStorage {
  Future<GameEconomyState?> load();

  Future<void> save(GameEconomyState state);
}

class SharedPreferencesGameEconomyStorage implements GameEconomyStorage {
  const SharedPreferencesGameEconomyStorage();

  static const String _coinsKey = 'economy.yCoins';
  static const String _ownedItemsKey = 'economy.ownedItems';
  static const String _equippedCharacterKey = 'economy.equippedCharacter';
  static const String _equippedTowerKey = 'economy.equippedTower';
  static const String _equippedArenaKey = 'economy.equippedArena';
  static const String _passPointsKey = 'economy.passPoints';
  static const String _premiumPassKey = 'economy.premiumPass';
  static const String _claimedRewardsKey = 'economy.claimedRewards';

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
      passPoints: (preferences.getInt(_passPointsKey) ?? fallback.passPoints)
          .clamp(0, 999999),
      premiumPassActive:
          preferences.getBool(_premiumPassKey) ?? fallback.premiumPassActive,
      claimedRewardIds: <String>{
        ...preferences.getStringList(_claimedRewardsKey) ?? <String>[],
      },
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
    await preferences.setInt(_passPointsKey, state.passPoints);
    await preferences.setBool(_premiumPassKey, state.premiumPassActive);
    await preferences.setStringList(
      _claimedRewardsKey,
      state.claimedRewardIds.toList()..sort(),
    );
  }
}
