import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/ads/application/ad_placement_providers.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page.dart';

void main() {
  test('free entitlement triggers the requested placement', () async {
    final _RecordingAdService service = _RecordingAdService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        adPlacementServiceProvider.overrideWithValue(service),
        hiredPassStatusProvider.overrideWith((Ref ref) async => _status(false)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hiredPassStatusProvider.future);

    container
        .read(adPlacementGateProvider)
        .triggerIfEligible(AdPlacement.practiceResultExit);

    expect(service.placements, <AdPlacement>[AdPlacement.practiceResultExit]);
  });

  test('ad-free entitlement suppresses every placement', () async {
    final _RecordingAdService service = _RecordingAdService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        adPlacementServiceProvider.overrideWithValue(service),
        hiredPassStatusProvider.overrideWith((Ref ref) async => _status(true)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hiredPassStatusProvider.future);

    container
        .read(adPlacementGateProvider)
        .triggerIfEligible(AdPlacement.publicPvpResultExit);

    expect(service.placements, isEmpty);
  });

  test('unknown entitlement is treated as not ad-free', () {
    final _RecordingAdService service = _RecordingAdService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        adPlacementServiceProvider.overrideWithValue(service),
        hiredPassStatusProvider.overrideWith(
          (Ref ref) => Future<HiredPassStatus>.error(StateError('offline')),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(adPlacementGateProvider)
        .triggerIfEligible(AdPlacement.practiceResultExit);

    expect(service.placements, <AdPlacement>[AdPlacement.practiceResultExit]);
  });

  test('a result session triggers at most once until reset', () async {
    final _RecordingAdService service = _RecordingAdService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        adPlacementServiceProvider.overrideWithValue(service),
        hiredPassStatusProvider.overrideWith((Ref ref) async => _status(false)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(hiredPassStatusProvider.future);
    final ResultExitAdSession session = ResultExitAdSession();
    final AdPlacementGate gate = container.read(adPlacementGateProvider);

    session
      ..triggerOnce(gate, AdPlacement.publicPvpResultExit)
      ..triggerOnce(gate, AdPlacement.publicPvpResultExit);
    expect(service.placements, hasLength(1));

    session
      ..reset()
      ..triggerOnce(gate, AdPlacement.publicPvpResultExit);
    expect(service.placements, hasLength(2));
  });

  test('only public Casual and Ranked results are ad eligible', () {
    expect(
      isPublicPvpResultAdEligible(
        battleMode: BattleMode.online,
        matchmakingMode: OnlineMatchmakingMode.casual,
      ),
      isTrue,
    );
    expect(
      isPublicPvpResultAdEligible(
        battleMode: BattleMode.online,
        matchmakingMode: OnlineMatchmakingMode.ranked,
      ),
      isTrue,
    );
    expect(
      isPublicPvpResultAdEligible(
        battleMode: BattleMode.online,
        matchmakingMode: OnlineMatchmakingMode.bot,
      ),
      isFalse,
    );
    expect(
      isPublicPvpResultAdEligible(
        battleMode: BattleMode.bot,
        matchmakingMode: OnlineMatchmakingMode.casual,
      ),
      isFalse,
    );
  });
}

HiredPassStatus _status(bool adFree) {
  return HiredPassStatus(
    seasonId: 'season',
    passPoints: 100,
    premiumActive: adFree,
    adFree: adFree,
    expiresAt: adFree ? DateTime.utc(2026, 9) : null,
    missions: const <HiredPassMission>[],
    rewards: const <HiredPassReward>[],
    claimedRewardIds: const <String>{},
  );
}

class _RecordingAdService extends AdPlacementService {
  final List<AdPlacement> placements = <AdPlacement>[];

  @override
  void trigger(AdPlacement placement) => placements.add(placement);
}
