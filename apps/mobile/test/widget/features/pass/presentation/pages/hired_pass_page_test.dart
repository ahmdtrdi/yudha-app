import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';
import 'package:yudha_mobile/features/pass/presentation/pages/hired_pass_page.dart';

void main() {
  testWidgets('renders reward lanes and distinct clay reward states', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gameEconomyProvider.overrideWith(
            (Ref ref) => GameEconomyController(),
          ),
          hiredPassStatusProvider.overrideWith((Ref ref) async => _status()),
        ],
        child: const MaterialApp(home: HiredPassPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('reward-track-table')),
      300,
    );

    expect(find.text('FREE PASS'), findsOneWidget);
    expect(find.text('PREMIUM PASS'), findsOneWidget);
    expect(find.text('FREE'), findsNothing);
    expect(find.text('PREMIUM'), findsNothing);

    final DecoratedBox premiumLane = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('premium-reward-lane')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final BoxDecoration laneDecoration =
        premiumLane.decoration as BoxDecoration;
    expect(laneDecoration.color, const Color(0xFFECE5FA));
    expect(laneDecoration.borderRadius, BorderRadius.circular(22));

    final Finder claimedReward = find.byKey(
      const ValueKey<String>('pass-reward-free-100-coins'),
    );
    final Finder claimableReward = find.byKey(
      const ValueKey<String>('pass-reward-premium-100-coins'),
    );
    final Finder lockedReward = find.byKey(
      const ValueKey<String>('pass-reward-free-300-coins'),
    );
    final Finder emptyPremiumReward = find.byKey(
      const ValueKey<String>('pass-reward-empty-premium-900'),
    );

    expect(claimedReward, findsOneWidget);
    expect(claimableReward, findsOneWidget);
    expect(lockedReward, findsOneWidget);
    expect(emptyPremiumReward, findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('100 Y-Coin, sudah diklaim')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('250 Y-Coin, dapat diklaim')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('150 Y-Coin, terkunci')),
      findsOneWidget,
    );
    final Finder premiumTower = find.byKey(
      const ValueKey<String>('pass-reward-premium-300-tower'),
    );
    final Finder premiumCharacter = find.byKey(
      const ValueKey<String>('pass-reward-premium-600-character'),
    );
    expect(
      find.descendant(of: premiumTower, matching: find.text('Benteng Bara')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('y-coin-premium-300-tower')),
      findsNothing,
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('reward-item-clip-premium-300-tower'),
        ),
      ),
      const Size.square(46),
    );
    expect(
      find.descendant(of: premiumCharacter, matching: find.text('Pip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('y-coin-premium-600-character')),
      findsNothing,
    );
    final ClipRRect characterClip = tester.widget<ClipRRect>(
      find.byKey(
        const ValueKey<String>('reward-item-clip-premium-600-character'),
      ),
    );
    expect(characterClip.borderRadius, BorderRadius.circular(10));
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('y-coin-free-100-coins')),
      ),
      const Size.square(38),
    );

    final InkWell claimedInk = tester.widget<InkWell>(
      find.descendant(of: claimedReward, matching: find.byType(InkWell)),
    );
    final InkWell claimableInk = tester.widget<InkWell>(
      find.descendant(of: claimableReward, matching: find.byType(InkWell)),
    );
    final InkWell lockedInk = tester.widget<InkWell>(
      find.descendant(of: lockedReward, matching: find.byType(InkWell)),
    );
    expect(claimedInk.onTap, isNull);
    expect(claimableInk.onTap, isNotNull);
    expect(lockedInk.onTap, isNull);

    final Rect claimedRect = tester.getRect(claimedReward);
    final Rect claimedFaceRect = tester.getRect(
      find.descendant(of: claimedReward, matching: find.byType(InkWell)),
    );
    final Rect claimableRect = tester.getRect(claimableReward);
    final Rect claimableFaceRect = tester.getRect(
      find.descendant(of: claimableReward, matching: find.byType(InkWell)),
    );
    expect(claimedFaceRect.top, closeTo(claimedRect.top + 7, 0.1));
    expect(claimedFaceRect.bottom, closeTo(claimedRect.bottom, 0.1));
    expect(claimableFaceRect.top, closeTo(claimableRect.top, 0.1));
    expect(claimableFaceRect.bottom, closeTo(claimableRect.bottom - 7, 0.1));

    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

HiredPassStatus _status() {
  return const HiredPassStatus(
    seasonId: 'season-01',
    passPoints: 100,
    premiumActive: true,
    adFree: true,
    expiresAt: null,
    missions: <HiredPassMission>[],
    rewards: <HiredPassReward>[
      HiredPassReward(
        id: 'free-100-coins',
        track: 'free',
        pointsRequired: 100,
        label: '100 Y-Coin',
        coins: 100,
      ),
      HiredPassReward(
        id: 'premium-100-coins',
        track: 'premium',
        pointsRequired: 100,
        label: '250 Y-Coin',
        coins: 250,
      ),
      HiredPassReward(
        id: 'free-300-coins',
        track: 'free',
        pointsRequired: 300,
        label: '150 Y-Coin',
        coins: 150,
      ),
      HiredPassReward(
        id: 'premium-300-tower',
        track: 'premium',
        pointsRequired: 300,
        label: '150 Y-Coin + Benteng Bara',
        coins: 150,
        itemId: 'tower-benteng-bara',
      ),
      HiredPassReward(
        id: 'free-600-coins',
        track: 'free',
        pointsRequired: 600,
        label: '300 Y-Coin',
        coins: 300,
      ),
      HiredPassReward(
        id: 'premium-600-character',
        track: 'premium',
        pointsRequired: 600,
        label: '300 Y-Coin + Pip',
        coins: 300,
        itemId: 'character-basic-pip',
      ),
      HiredPassReward(
        id: 'free-900-coins',
        track: 'free',
        pointsRequired: 900,
        label: '450 Y-Coin',
        coins: 450,
      ),
    ],
    claimedRewardIds: <String>{'free-100-coins'},
  );
}
