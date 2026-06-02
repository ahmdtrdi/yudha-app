import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/interview/application/interview_controller.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/repositories/backend_interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';

final Provider<InterviewApiConfig> interviewApiConfigProvider =
    Provider<InterviewApiConfig>((Ref ref) => const InterviewApiConfig());

final Provider<InterviewRepository> interviewRepositoryProvider =
    Provider<InterviewRepository>(
      (Ref ref) => BackendInterviewRepository(
        config: ref.watch(interviewApiConfigProvider),
      ),
    );

final StateNotifierProviderFamily<
  InterviewController,
  InterviewState,
  InterviewLaunchConfig
>
interviewControllerProvider =
    StateNotifierProvider.family<
      InterviewController,
      InterviewState,
      InterviewLaunchConfig
    >(
      (Ref ref, InterviewLaunchConfig config) => InterviewController(
        repository: ref.watch(interviewRepositoryProvider),
        config: config,
      ),
    );
