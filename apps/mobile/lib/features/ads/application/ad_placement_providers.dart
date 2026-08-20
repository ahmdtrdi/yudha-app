import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';

enum AdPlacement { practiceResultExit, publicPvpResultExit }

abstract class AdPlacementService {
  const AdPlacementService();

  void trigger(AdPlacement placement);
}

class StubAdPlacementService extends AdPlacementService {
  const StubAdPlacementService();

  @override
  void trigger(AdPlacement placement) {
    log('Ad placement stub: ${placement.name}', name: 'AdPlacement');
  }
}

final Provider<AdPlacementService> adPlacementServiceProvider =
    Provider<AdPlacementService>((Ref ref) => const StubAdPlacementService());

class AdPlacementGate {
  const AdPlacementGate(this._ref);

  final Ref _ref;

  void triggerIfEligible(AdPlacement placement) {
    final AsyncValue<HiredPassStatus> status = _ref.read(
      hiredPassStatusProvider,
    );
    final bool adFree = status.asData?.value.adFree == true;
    if (!adFree) {
      _ref.read(adPlacementServiceProvider).trigger(placement);
    }
  }
}

final Provider<AdPlacementGate> adPlacementGateProvider =
    Provider<AdPlacementGate>((Ref ref) => AdPlacementGate(ref));

class ResultExitAdSession {
  bool _triggered = false;

  void triggerOnce(AdPlacementGate gate, AdPlacement placement) {
    if (_triggered) return;
    _triggered = true;
    gate.triggerIfEligible(placement);
  }

  void reset() => _triggered = false;
}
