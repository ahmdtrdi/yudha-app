import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/store/presentation/pages/store_page.dart';

void main() {
  testWidgets('Y-Coin purchase is unavailable without Google Play Billing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
        gameEconomyRepositoryProvider.overrideWithValue(
          _ImmediateEconomyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StorePage()),
      ),
    );
    await tester.pump();

    expect(container.read(gameEconomyProvider).yCoins, 3000);

    await tester.tap(find.byKey(const ValueKey<String>('y-coin-balance')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('y-coin-purchases-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Pembelian Y-Coin belum tersedia'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('top-up-beta-100')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('confirm-dummy-payment-button')),
      findsNothing,
    );
    expect(container.read(gameEconomyProvider).yCoins, 3000);
  });

  testWidgets('shows a blocking progress overlay while purchase is pending', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _DelayedEconomyRepository repository = _DelayedEconomyRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
        gameEconomyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StorePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('store-item-character-basic-pip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beli & pakai'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('store-transaction-loading')),
      findsOneWidget,
    );
    expect(find.text('Memproses pembelian Opy...'), findsOneWidget);

    repository.completePurchase();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('store-transaction-loading')),
      findsNothing,
    );
    expect(
      container.read(gameEconomyProvider).owns('character-basic-pip'),
      isTrue,
    );
  });

  testWidgets('marks cached Store data unavailable when server sync fails', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
        gameEconomyRepositoryProvider.overrideWithValue(
          _FailingEconomyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StorePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('store-economy-sync-banner')),
      findsOneWidget,
    );
    expect(find.text('Sinkronisasi diperlukan'), findsWidgets);
    expect(container.read(gameEconomyProvider).isAuthoritative, isFalse);
  });
}

class _MemoryEconomyStorage implements GameEconomyStorage {
  GameEconomyState? saved;

  @override
  Future<GameEconomyState?> load() async => saved;

  @override
  Future<void> save(GameEconomyState state) async {
    saved = state;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }
}

class _DelayedEconomyRepository extends GameEconomyRepository {
  final Completer<AuthoritativeEconomySnapshot> _purchaseCompleter =
      Completer<AuthoritativeEconomySnapshot>();

  AuthoritativeEconomySnapshot get _initial => AuthoritativeEconomySnapshot(
    coins: 3000,
    energy: 10,
    maxEnergy: 10,
    dailyRefillTarget: 10,
    isPro: false,
    ownedItemIds: <String>{
      GameEconomyCatalog.defaultCharacterId,
      GameEconomyCatalog.defaultTowerId,
    },
    characterId: GameEconomyCatalog.defaultCharacterId,
    towerId: GameEconomyCatalog.defaultTowerId,
    arenaId: GameEconomyCatalog.defaultArenaId,
    items: GameEconomyCatalog.cosmetics,
  );

  @override
  Future<AuthoritativeEconomySnapshot> fetch() async => _initial;

  @override
  Future<AuthoritativeEconomySnapshot> grantBetaCredit({
    int coins = 100,
  }) async => _snapshot(coins: 3000 + coins);

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(CosmeticItem item) {
    return _purchaseCompleter.future;
  }

  @override
  Future<AuthoritativeEconomySnapshot> purchaseEnergyPack(String packageId) {
    return Future<AuthoritativeEconomySnapshot>.value(_initial);
  }

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async {
    return _initial;
  }

  void completePurchase() {
    _purchaseCompleter.complete(
      AuthoritativeEconomySnapshot(
        coins: 2500,
        energy: 10,
        maxEnergy: 10,
        dailyRefillTarget: 10,
        isPro: false,
        ownedItemIds: <String>{
          GameEconomyCatalog.defaultCharacterId,
          GameEconomyCatalog.defaultTowerId,
          'character-basic-pip',
        },
        characterId: 'character-basic-pip',
        towerId: GameEconomyCatalog.defaultTowerId,
        arenaId: GameEconomyCatalog.defaultArenaId,
        items: GameEconomyCatalog.cosmetics,
      ),
    );
  }

  AuthoritativeEconomySnapshot _snapshot({required int coins}) {
    return AuthoritativeEconomySnapshot(
      coins: coins,
      energy: _initial.energy,
      maxEnergy: _initial.maxEnergy,
      dailyRefillTarget: _initial.dailyRefillTarget,
      isPro: _initial.isPro,
      ownedItemIds: _initial.ownedItemIds,
      characterId: _initial.characterId,
      towerId: _initial.towerId,
      arenaId: _initial.arenaId,
      items: GameEconomyCatalog.cosmetics,
    );
  }
}

class _ImmediateEconomyRepository extends _DelayedEconomyRepository {
  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(CosmeticItem item) {
    return Future<AuthoritativeEconomySnapshot>.value(_initial);
  }
}

class _FailingEconomyRepository extends GameEconomyRepository {
  @override
  Future<AuthoritativeEconomySnapshot> fetch() {
    return Future<AuthoritativeEconomySnapshot>.error(StateError('offline'));
  }

  @override
  Future<AuthoritativeEconomySnapshot> grantBetaCredit({int coins = 100}) =>
      fetch();

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(CosmeticItem item) =>
      fetch();

  @override
  Future<AuthoritativeEconomySnapshot> purchaseEnergyPack(String packageId) =>
      fetch();

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) => fetch();
}
