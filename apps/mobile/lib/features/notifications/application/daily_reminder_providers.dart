import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/notifications/application/daily_reminder_controller.dart';
import 'package:yudha_mobile/features/notifications/data/daily_reminder_repository.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

final Provider<FirebaseMessaging?> firebaseMessagingProvider =
    Provider<FirebaseMessaging?>((Ref ref) {
      return Firebase.apps.isEmpty ? null : FirebaseMessaging.instance;
    });

final Provider<DailyReminderRepository> dailyReminderRepositoryProvider =
    Provider<DailyReminderRepository>((Ref ref) {
      return DailyReminderRepository(
        config: DailyReminderApiConfig(
          accessToken: ref.watch(authAccessTokenProvider),
        ),
      );
    });

final StateNotifierProvider<DailyReminderController, DailyReminderState>
dailyReminderProvider =
    StateNotifierProvider<DailyReminderController, DailyReminderState>(
      (Ref ref) => DailyReminderController(
        repository: ref.watch(dailyReminderRepositoryProvider),
        isAuthenticated: ref.watch(isAuthenticatedProvider),
        messaging: ref.watch(firebaseMessagingProvider),
        onForegroundMessage: () =>
            ref.read(playerProgressProvider.notifier).hydrateFromRepository(),
      ),
    );
