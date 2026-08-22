import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';

void main() {
  test('missing repository never permits a local economy mutation', () async {
    final _MemoryStorage storage = _MemoryStorage(
      GameEconomyState.initial().copyWith(yCoins: 900),
    );
    final GameEconomyController controller = GameEconomyController(
      storage: storage,
    );
    await pumpEventQueue();
    final GameEconomyState before = controller.state;

    final EconomyActionResult result = await controller.topUpAuthoritative(
      GameEconomyCatalog.topUpPackages.first,
    );

    expect(result.success, isFalse);
    expect(controller.state.yCoins, before.yCoins);
    expect(controller.state.syncStatus, EconomySyncStatus.syncUnavailable);
    expect(controller.state.yCoins, 0);
    expect(storage.value, isNull);
  });

  test('failed startup sync keeps cache visibly non-authoritative', () async {
    final GameEconomyState cached = GameEconomyState.initial().copyWith(
      yCoins: 900,
      dataSource: EconomyDataSource.cache,
    );
    final GameEconomyController controller = GameEconomyController(
      storage: _MemoryStorage(cached),
      repository: _FakeRepository(failFetch: true),
    );
    await pumpEventQueue();

    expect(controller.state.yCoins, 900);
    expect(controller.state.dataSource, EconomyDataSource.cache);
    expect(controller.state.syncStatus, EconomySyncStatus.syncUnavailable);

    final EconomyActionResult result = await controller.purchaseAuthoritative(
      GameEconomyCatalog.characters[1],
    );
    expect(result.success, isFalse);
    expect(controller.state.owns(GameEconomyCatalog.characters[1].id), isFalse);
  });

  test('successful mutation replaces state with server snapshot', () async {
    final _FakeRepository repository = _FakeRepository();
    final GameEconomyController controller = GameEconomyController(
      repository: repository,
    );
    await pumpEventQueue();

    expect(controller.state.isAuthoritative, isTrue);
    expect(controller.state.yCoins, 500);

    final EconomyActionResult result = await controller.topUpAuthoritative(
      GameEconomyCatalog.topUpPackages.first,
    );

    expect(result.success, isTrue);
    expect(controller.state.yCoins, 600);
    expect(repository.betaCreditCalls, 1);
  });

  test('all top-up packages grant beta credit in beta mode', () async {
    final _FakeRepository repository = _FakeRepository();
    final GameEconomyController controller = GameEconomyController(
      repository: repository,
    );
    await pumpEventQueue();

    final EconomyActionResult result = await controller.topUpAuthoritative(
      GameEconomyCatalog.topUpPackages[1],
    );

    expect(result.success, isTrue);
    expect(repository.betaCreditCalls, 1);
    expect(controller.state.yCoins, 1000);
  });
}

class _MemoryStorage implements GameEconomyStorage {
  _MemoryStorage(this.value);

  GameEconomyState? value;

  @override
  Future<GameEconomyState?> load() async => value;

  @override
  Future<void> save(GameEconomyState state) async => value = state;

  @override
  Future<void> clear() async => value = null;
}

class _FakeRepository extends GameEconomyRepository {
  _FakeRepository({this.failFetch = false});

  final bool failFetch;
  int betaCreditCalls = 0;

  AuthoritativeEconomySnapshot _snapshot(int coins) {
    return AuthoritativeEconomySnapshot(
      coins: coins,
      ownedItemIds: const <String>{
        GameEconomyCatalog.defaultCharacterId,
        GameEconomyCatalog.defaultTowerId,
      },
      characterId: GameEconomyCatalog.defaultCharacterId,
      towerId: GameEconomyCatalog.defaultTowerId,
      arenaId: GameEconomyCatalog.defaultArenaId,
      items: GameEconomyCatalog.cosmetics,
    );
  }

  @override
  Future<AuthoritativeEconomySnapshot> fetch() async {
    if (failFetch) throw StateError('offline');
    return _snapshot(500);
  }

  @override
  Future<AuthoritativeEconomySnapshot> grantBetaCredit({
    int coins = 100,
  }) async {
    betaCreditCalls += 1;
    return _snapshot(500 + coins);
  }

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(
    CosmeticItem item,
  ) async => _snapshot(100);

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async => _snapshot(500);
}
