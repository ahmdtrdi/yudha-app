import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_history_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_history_state.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/backend_practice_repository.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';

final Provider<PracticeApiConfig> practiceApiConfigProvider =
    Provider<PracticeApiConfig>(
      (Ref ref) =>
          PracticeApiConfig(accessToken: ref.watch(authAccessTokenProvider)),
    );

final Provider<PracticeRepository> practiceRepositoryProvider =
    Provider<PracticeRepository>(
      (Ref ref) => BackendPracticeRepository(
        config: ref.watch(practiceApiConfigProvider),
      ),
    );

final StateNotifierProvider<PracticeController, PracticeState>
practiceControllerProvider =
    StateNotifierProvider<PracticeController, PracticeState>((Ref ref) {
      ref.watch(profileSettingsProvider.select((settings) => settings.target));
      return PracticeController(
        repository: ref.watch(practiceRepositoryProvider),
      );
    });

final StateNotifierProvider<PracticeHistoryController, PracticeHistoryState>
practiceHistoryControllerProvider =
    StateNotifierProvider<PracticeHistoryController, PracticeHistoryState>(
      (Ref ref) => PracticeHistoryController(
        repository: ref.watch(practiceRepositoryProvider),
      ),
    );
