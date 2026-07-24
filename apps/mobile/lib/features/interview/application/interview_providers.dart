import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_controller.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/repositories/backend_interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

final Provider<InterviewApiConfig> interviewApiConfigProvider =
    Provider<InterviewApiConfig>(
      (Ref ref) =>
          InterviewApiConfig(accessToken: ref.watch(authAccessTokenProvider)),
    );

final Provider<InterviewRepository> interviewRepositoryProvider =
    Provider<InterviewRepository>(
      (Ref ref) => BackendInterviewRepository(
        config: ref.watch(interviewApiConfigProvider),
      ),
    );

final FutureProvider<List<InterviewSessionSummaryRecord>>
interviewSessionsProvider = FutureProvider<List<InterviewSessionSummaryRecord>>(
  (Ref ref) {
    return ref.watch(interviewRepositoryProvider).listSessions();
  },
);

final FutureProviderFamily<InterviewSessionDetailRecord, String>
interviewSessionDetailProvider =
    FutureProvider.family<InterviewSessionDetailRecord, String>((
      Ref ref,
      String sessionId,
    ) {
      return ref.watch(interviewRepositoryProvider).getSession(sessionId);
    });

final AutoDisposeStateNotifierProviderFamily<
  InterviewController,
  InterviewState,
  InterviewLaunchConfig
>
interviewControllerProvider = StateNotifierProvider.autoDispose
    .family<InterviewController, InterviewState, InterviewLaunchConfig>(
      (Ref ref, InterviewLaunchConfig config) => InterviewController(
        repository: ref.watch(interviewRepositoryProvider),
        config: config,
        onSessionChanged: (String sessionId) {
          ref.invalidate(interviewSessionsProvider);
          ref.invalidate(interviewSessionDetailProvider(sessionId));
        },
      ),
    );
