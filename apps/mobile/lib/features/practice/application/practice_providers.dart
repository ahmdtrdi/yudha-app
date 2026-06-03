import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/application/practice_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/backend_practice_repository.dart';
import 'package:yudha_mobile/features/practice/data/repositories/mock_practice_repository.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

final Provider<PracticeApiConfig> practiceApiConfigProvider =
    Provider<PracticeApiConfig>((Ref ref) => const PracticeApiConfig());

final Provider<PracticeRepository> practiceRepositoryProvider =
    Provider<PracticeRepository>(
      (Ref ref) => BackendPracticeRepository(
        config: ref.watch(practiceApiConfigProvider),
        fallbackRepository: const MockPracticeRepository(),
      ),
    );

final StateNotifierProvider<PracticeController, PracticeState>
practiceControllerProvider =
    StateNotifierProvider<PracticeController, PracticeState>(
      (Ref ref) => PracticeController(
        repository: ref.watch(practiceRepositoryProvider),
        target: ref.watch(profileSettingsProvider).target ?? ProfileTarget.cpns,
      ),
    );
