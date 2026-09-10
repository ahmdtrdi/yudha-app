import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yudha_mobile/features/notifications/application/daily_reminder_controller.dart';
import 'package:yudha_mobile/features/notifications/data/daily_reminder_repository.dart';
import 'package:yudha_mobile/features/notifications/data/reminder_messaging.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

class FakeMessaging implements ReminderMessaging {
  ReminderPermissionStatus permission = ReminderPermissionStatus.denied;
  Object? failure;
  String? token = 'test-token';
  int calls = 0;
  int failuresLeft = 0;
  Completer<String?>? pending;
  final tokens = StreamController<String>.broadcast();
  @override
  Future<ReminderPermissionStatus> getPermission() async => permission;
  @override
  Future<ReminderPermissionStatus> requestPermission() async => permission;
  @override
  Future<String?> getToken() async {
    calls++;
    if (pending != null) return pending!.future;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw failure!;
    }
    return token;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Stream<String> get onTokenRefresh => tokens.stream;
  @override
  Stream<RemoteMessage> get onOpened => const Stream.empty();
  @override
  Stream<RemoteMessage> get onForeground => const Stream.empty();
}

class FakeRepository extends DailyReminderRepository {
  FakeRepository() : super(config: const DailyReminderApiConfig());
  DailyReminderPreferences preferences = DailyReminderPreferences.defaults();
  int registrations = 0;
  int updates = 0;
  bool failRegistration = false;
  String? registeredToken;
  @override
  Future<DailyReminderPreferences> fetchPreferences() async => preferences;
  @override
  Future<DailyReminderPreferences> updatePreferences(
    Map<String, Object?> update,
  ) async {
    updates++;
    return preferences = preferences.copyWith(
      enabled: update['enabled'] as bool?,
    );
  }

  @override
  Future<void> registerInstallation({
    required String installationId,
    required String token,
    required String platform,
    required String timeZone,
  }) async {
    registrations++;
    if (failRegistration) {
      throw const DailyReminderApiException('server failed');
    }
    registeredToken = token;
  }

  @override
  Future<void> removeInstallation(String installationId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMessaging messaging;
  late FakeRepository repository;
  late DailyReminderController controller;
  late List<Duration> delays;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    messaging = FakeMessaging();
    repository = FakeRepository();
    delays = <Duration>[];
    controller = DailyReminderController(
      repository: repository,
      isAuthenticated: true,
      userId: 'account-a',
      messagingClient: messaging,
      timeZone: () async => 'Asia/Jakarta',
      delay: (duration) async {
        delays.add(duration);
      },
    );
    await controller.initialized;
  });
  tearDown(() async {
    if (controller.mounted) controller.dispose();
    await messaging.tokens.close();
  });

  test('denied permission never enables or registers', () async {
    expect(await controller.requestPermissionAndEnable(), isFalse);
    expect(repository.updates, 0);
    expect(messaging.calls, 0);
  });
  test(
    'transient FCM failure retries twice and only enables after success',
    () async {
      messaging.permission = ReminderPermissionStatus.authorized;
      messaging.failure = FirebaseException(
        plugin: 'firebase_messaging',
        code: 'unknown',
        message: 'java.io.IOException: FCM Registration failed!',
      );
      messaging.failuresLeft = 2;
      expect(await controller.requestPermissionAndEnable(), isTrue);
      expect(messaging.calls, 3);
      expect(delays, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(repository.updates, 1);
      expect(
        controller.state.registrationStatus,
        ReminderRegistrationStatus.registered,
      );
    },
  );
  test(
    'empty token does not silently enable; subsequent enable retries',
    () async {
      messaging.permission = ReminderPermissionStatus.authorized;
      messaging.token = null;
      expect(await controller.requestPermissionAndEnable(), isFalse);
      expect(repository.updates, 0);
      expect(messaging.calls, 3);
      expect(controller.state.errorMessage, isNot(contains('java.io')));
      messaging.token = 'valid';
      expect(await controller.requestPermissionAndEnable(), isTrue);
      expect(messaging.calls, 4);
    },
  );
  test('missing Play services is actionable and not retried', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    messaging.failure = PlatformException(code: 'play_services_unavailable');
    messaging.failuresLeft = 3;
    expect(await controller.requestPermissionAndEnable(), isFalse);
    expect(messaging.calls, 1);
    expect(controller.state.errorMessage, contains('Google Play services'));
  });
  test('backend failure cannot enable reminders', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    repository.failRegistration = true;
    expect(await controller.requestPermissionAndEnable(), isFalse);
    expect(repository.updates, 0);
    expect(
      controller.state.registrationStatus,
      ReminderRegistrationStatus.failed,
    );
  });
  test('concurrent background syncs share one registration', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    await Future.wait([
      controller.syncInstallation(force: true),
      controller.syncInstallation(force: true),
    ]);
    expect(repository.registrations, 1);
  });
  test('account switch does not reuse another account sync cache', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    await controller.syncInstallation(force: true);
    final other = DailyReminderController(
      repository: repository,
      isAuthenticated: true,
      userId: 'account-b',
      messagingClient: messaging,
      timeZone: () async => 'Asia/Jakarta',
    );
    await other.initialized;
    other.dispose();
    expect(repository.registrations, 2);
  });
  test('logout clears registration cache', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    await controller.syncInstallation(force: true);
    await controller.unregisterBeforeLogout();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('notifications.sync.')),
      isEmpty,
    );
  });
  test(
    'switching back to a cached account reclaims the installation',
    () async {
      messaging.permission = ReminderPermissionStatus.authorized;
      await controller.syncInstallation(force: true);
      final other = DailyReminderController(
        repository: repository,
        isAuthenticated: true,
        userId: 'account-b',
        messagingClient: messaging,
        timeZone: () async => 'Asia/Jakarta',
      );
      await other.initialized;
      other.dispose();
      await controller.syncInstallation();
      expect(repository.registrations, 3);
    },
  );
  test(
    'dispose while token is pending prevents registration and state writes',
    () async {
      messaging.permission = ReminderPermissionStatus.authorized;
      messaging.pending = Completer<String?>();
      final operation = controller.syncInstallation(force: true);
      while (messaging.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.dispose();
      messaging.pending!.complete('late-token');
      await operation;
      expect(repository.registrations, 0);
    },
  );
  test('token refresh failure is handled and recoverable', () async {
    messaging.permission = ReminderPermissionStatus.authorized;
    await controller.syncInstallation(force: true);
    repository.failRegistration = true;
    messaging.tokens.add('refreshed');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      controller.state.registrationStatus,
      ReminderRegistrationStatus.failed,
    );
    repository.failRegistration = false;
    messaging.token = 'refreshed';
    await controller.retryRegistration();
    expect(repository.registeredToken, 'refreshed');
  });
}
