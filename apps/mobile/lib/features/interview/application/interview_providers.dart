import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_controller.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/application/live_interview_coordinator.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';
import 'package:yudha_mobile/features/interview/data/repositories/backend_interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/live_interview_speech_client.dart';
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

final Provider<LiveInterviewAudioCapture Function()>
liveInterviewAudioCaptureFactoryProvider =
    Provider<LiveInterviewAudioCapture Function()>(
      (_) => createLiveInterviewAudioCapture,
    );

final Provider<LiveInterviewAudioPlayer Function()>
liveInterviewAudioPlayerFactoryProvider =
    Provider<LiveInterviewAudioPlayer Function()>(
      (_) => createLiveInterviewAudioPlayer,
    );

final Provider<LiveInterviewSpeechClient Function(String?)>
liveInterviewSpeechClientFactoryProvider =
    Provider<LiveInterviewSpeechClient Function(String?)>(
      (_) =>
          (String? token) => LiveInterviewSpeechClient(
            baseUrl: AppConfig.apiBaseUrl,
            accessToken: token,
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
    .family<InterviewController, InterviewState, InterviewLaunchConfig>((
      Ref ref,
      InterviewLaunchConfig config,
    ) {
      final InterviewController controller = InterviewController(
        repository: ref.watch(interviewRepositoryProvider),
        config: config,
        onSessionChanged: (String sessionId) {
          ref.invalidate(interviewSessionsProvider);
          ref.invalidate(interviewSessionDetailProvider(sessionId));
        },
      );
      if (config.responseStyle == 'voice') {
        final String? token = ref.watch(authAccessTokenProvider);
        controller.attachLiveCoordinator(
          LiveInterviewCoordinator(
            client: ref
                .watch(liveInterviewSpeechClientFactoryProvider)
                .call(token),
            capture: ref.watch(liveInterviewAudioCaptureFactoryProvider).call(),
            player: ref.watch(liveInterviewAudioPlayerFactoryProvider).call(),
            accessToken: token,
            questionAudioUrl: (String turnId) =>
                controller.getQuestionAudioUrl(turnId) ?? '',
            onPhase:
                (
                  LiveInterviewPhase phase, {
                  String? errorMessage,
                  bool clearError = false,
                }) => controller.updateLivePhase(
                  phase,
                  errorMessage: errorMessage,
                  clearError: clearError,
                ),
            onRecordingDuration: controller.updateLiveRecordingDuration,
            onTranscript: controller.applyLiveTranscript,
            onEvaluation: controller.applyLiveEvaluation,
            onQuestion: controller.applyLiveQuestion,
            onCompleted: controller.applyLiveCompletion,
            onTextFallback: controller.useTextFallback,
          ),
        );
      }
      return controller;
    });
