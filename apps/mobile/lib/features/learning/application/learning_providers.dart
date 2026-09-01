import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_controller.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/data/repositories/backend_learning_repository.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';

final Provider<LearningApiConfig> learningApiConfigProvider =
    Provider<LearningApiConfig>(
      (Ref ref) =>
          LearningApiConfig(accessToken: ref.watch(authAccessTokenProvider)),
    );

final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>(
      (Ref ref) => BackendLearningRepository(
        config: ref.watch(learningApiConfigProvider),
      ),
    );

final StateNotifierProvider<LearningController, LearningState>
learningControllerProvider =
    StateNotifierProvider<LearningController, LearningState>(
      (Ref ref) =>
          LearningController(repository: ref.watch(learningRepositoryProvider)),
    );
