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
  for (final String id in <String>[
    'character-legend-drakor',
    'character-rare-brock',
  ]) {
    testWidgets('$id shows Pro label without price or purchase action', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ImmediateEconomyRepository();
      final container = ProviderContainer(
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
      final card = find.byKey(ValueKey<String>('store-item-$id'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.descendant(
          of: find.byType(GridView).first,
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(card).onTap, isNull);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Skin eksklusif YUDHA Pro'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            id == 'character-legend-drakor' ? '2.200' : '1.100',
          ),
        ),
        findsNothing,
      );
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Beli & pakai'), findsNothing);
      expect(repository.purchaseCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('existing Drakor owner can equip without Pro or repurchasing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ImmediateEconomyRepository(ownsDrakor: true);
    final container = ProviderContainer(
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
    final card = find.byKey(
      const ValueKey<String>('store-item-character-legend-drakor'),
    );
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GridView).first,
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('Pakai')),
      findsOneWidget,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(repository.equippedCharacterId, 'character-legend-drakor');
    expect(repository.purchaseCalls, 0);
    expect(container.read(gameEconomyProvider).isPro, isFalse);
  });

  testWidgets('beta +100 top-up increases the Y-Coin balance', (
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
    await tester.tap(find.byKey(const ValueKey<String>('top-up-beta-100')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-dummy-payment-button')),
    );
    await tester.pumpAndSettle();

    expect(container.read(gameEconomyProvider).yCoins, 3100);
    expect(find.text('3.100'), findsNWidgets(2));
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
  _DelayedEconomyRepository({this.ownsDrakor = false});

  final bool ownsDrakor;
  int purchaseCalls = 0;
  String? equippedCharacterId;
  final Completer<AuthoritativeEconomySnapshot> _purchaseCompleter =
      Completer<AuthoritativeEconomySnapshot>();

  AuthoritativeEconomySnapshot get _initial => AuthoritativeEconomySnapshot(
    coins: 3000,
    energy: 10,
    maxEnergy: 100,
    dailyRefillTarget: 10,
    isPro: false,
    ownedItemIds: <String>{
      GameEconomyCatalog.defaultCharacterId,
      GameEconomyCatalog.defaultTowerId,
      if (ownsDrakor) 'character-legend-drakor',
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
    purchaseCalls += 1;
    return _purchaseCompleter.future;
  }

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async {
    equippedCharacterId = characterId;
    return _initial;
  }

  void completePurchase() {
    _purchaseCompleter.complete(
      AuthoritativeEconomySnapshot(
        coins: 2500,
        energy: 10,
        maxEnergy: 100,
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
      energy: 10,
      maxEnergy: 100,
      dailyRefillTarget: 10,
      isPro: false,
      ownedItemIds: _initial.ownedItemIds,
      characterId: _initial.characterId,
      towerId: _initial.towerId,
      arenaId: _initial.arenaId,
      items: GameEconomyCatalog.cosmetics,
    );
  }

  @override
  Future<AuthoritativeEconomySnapshot> purchaseEnergyPack(
    String packageId,
  ) async => _initial;
}

class _ImmediateEconomyRepository extends _DelayedEconomyRepository {
  _ImmediateEconomyRepository({super.ownsDrakor});

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(CosmeticItem item) {
    purchaseCalls += 1;
    return Future<AuthoritativeEconomySnapshot>.value(_initial);
  }
}

class _FailingEconomyRepository extends GameEconomyRepository {
  @override
  Future<AuthoritativeEconomySnapshot> purchaseEnergyPack(String packageId) =>
      fetch();

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
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) => fetch();
}
