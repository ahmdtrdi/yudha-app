import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/pvp_insights/application/pvp_insights_controller.dart';
import 'package:yudha_mobile/features/pvp_insights/data/pvp_insights_repository.dart';

final pvpInsightsRepositoryProvider = Provider<PvpInsightsRepository>(
  (Ref ref) => PvpInsightsRepository(
    accessToken: ref.watch(authAccessTokenProvider),
  ),
);

final pvpInsightsControllerProvider =
    StateNotifierProvider<PvpInsightsController, PvpInsightsState>(
      (Ref ref) => PvpInsightsController(
        ref.watch(pvpInsightsRepositoryProvider),
      ),
    );
