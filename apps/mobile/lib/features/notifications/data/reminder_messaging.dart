import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

abstract class ReminderMessaging {
  Future<ReminderPermissionStatus> getPermission();
  Future<ReminderPermissionStatus> requestPermission();
  Future<String?> getToken();
  Future<RemoteMessage?> getInitialMessage();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onOpened;
  Stream<RemoteMessage> get onForeground;
}

class FirebaseReminderMessaging implements ReminderMessaging {
  FirebaseReminderMessaging(this.messaging);
  final FirebaseMessaging messaging;

  ReminderPermissionStatus _permission(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => ReminderPermissionStatus.authorized,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently =>
          ReminderPermissionStatus.denied,
        AuthorizationStatus.notDetermined =>
          ReminderPermissionStatus.notDetermined,
      };

  @override
  Future<ReminderPermissionStatus> getPermission() async => _permission(
    (await messaging.getNotificationSettings()).authorizationStatus,
  );
  @override
  Future<ReminderPermissionStatus> requestPermission() async => _permission(
    (await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    )).authorizationStatus,
  );
  @override
  Future<String?> getToken() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final status = await const MethodChannel(
        'com.yudha.app/notifications',
      ).invokeMethod<int>('playServicesStatus');
      if (status != 0) {
        throw PlatformException(code: 'play_services_unavailable');
      }
    }
    return messaging.getToken(
      vapidKey: kIsWeb && AppConfig.firebaseWebVapidKey.isNotEmpty
          ? AppConfig.firebaseWebVapidKey
          : null,
    );
  }

  @override
  Future<RemoteMessage?> getInitialMessage() => messaging.getInitialMessage();
  @override
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;
  @override
  Stream<RemoteMessage> get onOpened => FirebaseMessaging.onMessageOpenedApp;
  @override
  Stream<RemoteMessage> get onForeground => FirebaseMessaging.onMessage;
}
