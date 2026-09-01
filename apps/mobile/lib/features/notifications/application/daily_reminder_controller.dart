import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/notifications/data/daily_reminder_repository.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

class DailyReminderController extends StateNotifier<DailyReminderState> {
  DailyReminderController({
    required DailyReminderRepository repository,
    required bool isAuthenticated,
    FirebaseMessaging? messaging,
    Future<void> Function()? onForegroundMessage,
  }) : _repository = repository,
       _isAuthenticated = isAuthenticated,
       _messaging = messaging,
       _onForegroundMessage = onForegroundMessage,
       super(DailyReminderState.initial()) {
    unawaited(_initialize());
  }

  static const String _installationIdKey = 'notifications.installationId';
  static const String _promptShownKey = 'notifications.permissionPromptShown';
  static const String _lastInstallationSyncKey =
      'notifications.lastInstallationSyncAt';
  static const String _lastTimeZoneKey = 'notifications.lastTimeZone';

  final DailyReminderRepository _repository;
  final bool _isAuthenticated;
  final FirebaseMessaging? _messaging;
  final Future<void> Function()? _onForegroundMessage;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _installationId;

  Future<void> _initialize() async {
    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final NotificationSettings settings = await messaging
          .getNotificationSettings();
      final permission = _mapPermission(settings.authorizationStatus);
      _installationId = await _loadInstallationId();
      state = state.copyWith(permissionStatus: permission, clearError: true);

      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleMessageTap,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((_) {
        final callback = _onForegroundMessage;
        if (callback != null) unawaited(callback());
      });
      _tokenSubscription = messaging.onTokenRefresh.listen((String token) {
        if (_isAuthenticated &&
            state.permissionStatus == ReminderPermissionStatus.authorized) {
          unawaited(_registerToken(token));
        }
      });

      final RemoteMessage? initial = await messaging.getInitialMessage();
      if (initial != null) _handleMessageTap(initial);
      if (_isAuthenticated) {
        final preferences = await _repository.fetchPreferences();
        state = state.copyWith(preferences: preferences);
        if (permission == ReminderPermissionStatus.authorized) {
          await syncInstallation();
        }
      }
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _message(error));
    }
  }

  Future<bool> requestPermissionAndEnable() async {
    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null || !_isAuthenticated) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final permission = _mapPermission(settings.authorizationStatus);
      if (permission != ReminderPermissionStatus.authorized) {
        state = state.copyWith(
          permissionStatus: permission,
          isSaving: false,
          errorMessage:
              'Izin notifikasi belum diberikan. Aktifkan melalui pengaturan perangkat atau browser.',
        );
        return false;
      }
      state = state.copyWith(permissionStatus: permission);
      await syncInstallation(force: true);
      final preferences = await _repository.updatePreferences(
        const <String, Object?>{'enabled': true},
      );
      state = state.copyWith(
        preferences: preferences,
        isSaving: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: _message(error));
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value &&
        state.permissionStatus != ReminderPermissionStatus.authorized) {
      await requestPermissionAndEnable();
      return;
    }
    await _save(<String, Object?>{'enabled': value});
  }

  Future<void> setMorningEnabled(bool value) =>
      _save(<String, Object?>{'morningEnabled': value});

  Future<void> setMorningTime(String value) =>
      _save(<String, Object?>{'morningTime': value});

  Future<void> setRescueEnabled(bool value) =>
      _save(<String, Object?>{'rescueEnabled': value});

  Future<void> setRescueTime(String value) =>
      _save(<String, Object?>{'rescueTime': value});

  Future<void> _save(Map<String, Object?> update) async {
    if (!_isAuthenticated) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final preferences = await _repository.updatePreferences(update);
      state = state.copyWith(
        preferences: preferences,
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: _message(error));
    }
  }

  Future<void> syncInstallation({bool force = false}) async {
    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null ||
        !_isAuthenticated ||
        state.permissionStatus != ReminderPermissionStatus.authorized) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final zone = await FlutterTimezone.getLocalTimezone();
    final lastSyncMs = preferences.getInt(_lastInstallationSyncKey);
    if (!force &&
        lastSyncMs != null &&
        preferences.getString(_lastTimeZoneKey) == zone.identifier &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastSyncMs),
            ) <
            const Duration(days: 7)) {
      return;
    }
    final String? token = await messaging.getToken(
      vapidKey: kIsWeb && AppConfig.firebaseWebVapidKey.isNotEmpty
          ? AppConfig.firebaseWebVapidKey
          : null,
    );
    if (token == null || token.isEmpty) return;
    await _registerToken(token, timeZone: zone.identifier);
  }

  Future<void> _registerToken(String token, {String? timeZone}) async {
    final String installationId = _installationId ??=
        await _loadInstallationId();
    final zone =
        timeZone ?? (await FlutterTimezone.getLocalTimezone()).identifier;
    await _repository.registerInstallation(
      installationId: installationId,
      token: token,
      platform: kIsWeb ? 'web' : 'android',
      timeZone: zone,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _lastInstallationSyncKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await preferences.setString(_lastTimeZoneKey, zone);
  }

  Future<void> unregisterBeforeLogout() async {
    final String? installationId = _installationId;
    if (!_isAuthenticated || installationId == null) return;
    try {
      await _repository.removeInstallation(installationId);
    } catch (_) {
      // Logout must remain available when the notification API is unreachable.
    }
  }

  Future<bool> claimFirstSuccessPrompt() async {
    if (!_isAuthenticated ||
        _messaging == null ||
        state.permissionStatus == ReminderPermissionStatus.authorized) {
      return false;
    }
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_promptShownKey) == true) return false;
    await preferences.setBool(_promptShownKey, true);
    return true;
  }

  Future<void> markOpened(String? deliveryId) async {
    if (deliveryId == null || deliveryId.isEmpty || !_isAuthenticated) return;
    try {
      await _repository.markOpened(deliveryId);
    } catch (_) {
      // Opening the destination is more important than analytics attribution.
    }
  }

  void clearPendingTap() {
    state = state.copyWith(clearPendingTap: true);
  }

  void _handleMessageTap(RemoteMessage message) {
    final String route = _safeRoute(message.data['route']?.toString());
    state = state.copyWith(
      pendingTap: ReminderNotificationTap(
        route: route,
        deliveryId: message.data['deliveryId']?.toString(),
      ),
    );
  }

  String _safeRoute(String? route) {
    return switch (route) {
      AppRoutes.lobby || AppRoutes.solo || AppRoutes.pvp => route!,
      AppRoutes.legacyPractice => AppRoutes.solo,
      _ => AppRoutes.lobby,
    };
  }

  Future<String> _loadInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_installationIdKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final created = const Uuid().v4();
    await preferences.setString(_installationIdKey, created);
    return created;
  }

  ReminderPermissionStatus _mapPermission(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => ReminderPermissionStatus.authorized,
      AuthorizationStatus.denied => ReminderPermissionStatus.denied,
      AuthorizationStatus.deniedPermanently => ReminderPermissionStatus.denied,
      AuthorizationStatus.notDetermined =>
        ReminderPermissionStatus.notDetermined,
    };
  }

  String _message(Object error) {
    return error.toString().replaceFirst(RegExp(r'^(Exception):\s*'), '');
  }

  @override
  void dispose() {
    unawaited(_tokenSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    super.dispose();
  }
}
