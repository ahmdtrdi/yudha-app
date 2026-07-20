import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_storage.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/store/presentation/pages/store_page.dart';

void main() {
  testWidgets('beta +100 top-up increases the Y-Coin balance', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        gameEconomyStorageProvider.overrideWithValue(_MemoryEconomyStorage()),
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

    expect(container.read(gameEconomyProvider).yCoins, 300);

    await tester.tap(find.byKey(const ValueKey<String>('y-coin-balance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('top-up-beta-100')));
    await tester.pump();

    expect(container.read(gameEconomyProvider).yCoins, 400);
    expect(find.text('400'), findsNWidgets(2));
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
}
