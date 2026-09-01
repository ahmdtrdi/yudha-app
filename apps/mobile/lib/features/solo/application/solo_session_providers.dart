import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

final Provider<SoloRepository> soloRepositoryProvider =
    Provider<SoloRepository>(
      (Ref ref) =>
          SoloRepository(accessToken: ref.watch(authAccessTokenProvider)),
    );

final StateNotifierProvider<SoloSessionController, SoloSessionState>
soloSessionControllerProvider =
    StateNotifierProvider<SoloSessionController, SoloSessionState>(
      (Ref ref) => SoloSessionController(ref.watch(soloRepositoryProvider)),
    );

final FutureProvider<SoloSession?> activeSoloSessionProvider =
    FutureProvider<SoloSession?>(
      (Ref ref) => ref.watch(soloRepositoryProvider).active(),
    );
