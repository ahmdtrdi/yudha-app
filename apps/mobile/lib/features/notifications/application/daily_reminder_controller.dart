import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/notifications/data/daily_reminder_repository.dart';
import 'package:yudha_mobile/features/notifications/data/reminder_messaging.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

class DailyReminderController extends StateNotifier<DailyReminderState> {
  DailyReminderController({
    required DailyReminderRepository repository,
    required bool isAuthenticated,
    String? userId,
    FirebaseMessaging? messaging,
    ReminderMessaging? messagingClient,
    Future<String> Function()? timeZone,
    Future<void> Function(Duration)? delay,
    Future<void> Function()? onForegroundMessage,
  }) : _repository = repository,
       _isAuthenticated = isAuthenticated,
       _userId = userId,
       _messaging =
           messagingClient ??
           (messaging == null ? null : FirebaseReminderMessaging(messaging)),
       _timeZone =
           timeZone ??
           (() async => (await FlutterTimezone.getLocalTimezone()).identifier),
       _delay = delay ?? Future<void>.delayed,
       _onForegroundMessage = onForegroundMessage,
       super(DailyReminderState.initial()) {
    initialized = _initialize();
  }

  static const String _installationIdKey = 'notifications.installationId';
  static const String _promptShownKey = 'notifications.permissionPromptShown';
  final DailyReminderRepository _repository;
  final bool _isAuthenticated;
  final String? _userId;
  final ReminderMessaging? _messaging;
  final Future<String> Function() _timeZone;
  final Future<void> Function(Duration) _delay;
  final Future<void> Function()? _onForegroundMessage;
  late final Future<void> initialized;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _installationId;
  Future<bool>? _syncInFlight;
  bool _loggingOut = false;
  bool get _active => mounted && !_loggingOut;
  String get _syncKey => 'notifications.sync.$_userId.$_installationId';
  String get _ownerKey => 'notifications.owner.$_installationId';
  void _publish(DailyReminderState next) {
    if (_active) state = next;
  }

  Future<void> _initialize() async {
    try {
      if (_isAuthenticated) {
        final preferences = await _repository.fetchPreferences();
        if (!_active) return;
        _publish(state.copyWith(preferences: preferences));
      }
      final messaging = _messaging;
      if (messaging == null || !_active) return;
      _installationId = await _loadInstallationId();
      final permission = await messaging.getPermission();
      if (!_active) return;
      _publish(state.copyWith(permissionStatus: permission));
      _openedSubscription = messaging.onOpened.listen(
        _handleMessageTap,
        onError: _streamError,
      );
      _foregroundSubscription = messaging.onForeground.listen((_) {
        unawaited(_handleForeground());
      }, onError: _streamError);
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(_handleTokenRefresh(token));
      }, onError: _streamError);
      final initial = await messaging.getInitialMessage();
      if (!_active) return;
      if (initial != null) _handleMessageTap(initial);
      if (_isAuthenticated &&
          permission == ReminderPermissionStatus.authorized) {
        await syncInstallation();
      }
    } catch (error) {
      if (_active) _publish(state.copyWith(errorMessage: _message(error)));
    } finally {
      if (_active) _publish(state.copyWith(isLoading: false));
    }
  }

  Future<void> _handleForeground() async {
    try {
      if (_active) await _onForegroundMessage?.call();
    } catch (error) {
      _diagnose(error);
    }
  }

  void _streamError(Object error) {
    if (_active) {
      _publish(
        state.copyWith(
          registrationStatus: ReminderRegistrationStatus.failed,
          errorMessage: _message(error),
        ),
      );
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (!_active ||
        !_isAuthenticated ||
        state.permissionStatus != ReminderPermissionStatus.authorized) {
      return;
    }
    await _syncInFlight;
    if (_active) await _startSync(force: true, token: token);
  }

  Future<bool> requestPermissionAndEnable() async {
    final messaging = _messaging;
    if (!_active || !_isAuthenticated || state.isSaving) return false;
    if (messaging == null) {
      _publish(
        state.copyWith(
          errorMessage: 'Notifikasi belum tersedia pada perangkat ini.',
        ),
      );
      return false;
    }
    _publish(state.copyWith(isSaving: true, clearError: true));
    try {
      final permission = await messaging.requestPermission();
      if (!_active) return false;
      _publish(state.copyWith(permissionStatus: permission));
      if (permission != ReminderPermissionStatus.authorized) {
        _publish(
          state.copyWith(
            errorMessage:
                'Izin notifikasi belum diberikan. Aktifkan melalui pengaturan perangkat atau browser.',
          ),
        );
        return false;
      }
      await _syncInFlight;
      if (!_active || !await _startSync(force: true)) return false;
      if (!_active) return false;
      final preferences = await _repository.updatePreferences(
        const <String, Object?>{'enabled': true},
      );
      if (!_active) return false;
      _publish(state.copyWith(preferences: preferences, clearError: true));
      return true;
    } catch (error) {
      if (_active) _publish(state.copyWith(errorMessage: _message(error)));
      return false;
    } finally {
      if (_active) _publish(state.copyWith(isSaving: false));
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      await requestPermissionAndEnable();
    } else {
      await _save(const <String, Object?>{'enabled': false});
    }
  }

  Future<void> retryRegistration() async {
    if (state.preferences.enabled) {
      await syncInstallation(force: true);
    } else {
      await requestPermissionAndEnable();
    }
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
    if (!_active || !_isAuthenticated || state.isSaving) return;
    _publish(state.copyWith(isSaving: true, clearError: true));
    try {
      final preferences = await _repository.updatePreferences(update);
      if (_active) {
        _publish(state.copyWith(preferences: preferences, clearError: true));
      }
    } catch (error) {
      if (_active) _publish(state.copyWith(errorMessage: _message(error)));
    } finally {
      if (_active) _publish(state.copyWith(isSaving: false));
    }
  }

  Future<void> syncInstallation({bool force = false}) async {
    await _startSync(force: force);
  }

  Future<bool> _startSync({required bool force, String? token}) {
    if (!_active || !_isAuthenticated || _messaging == null) {
      return Future.value(false);
    }
    return _syncInFlight ??= _sync(
      force: force,
      token: token,
    ).whenComplete(() => _syncInFlight = null);
  }

  Future<bool> _sync({required bool force, String? token}) async {
    try {
      final permission = await _messaging!.getPermission();
      if (!_active) return false;
      _publish(state.copyWith(permissionStatus: permission));
      if (permission != ReminderPermissionStatus.authorized) return false;
      _installationId ??= await _loadInstallationId();
      final preferences = await SharedPreferences.getInstance();
      final zone = await _timeZone();
      if (!_active) return false;
      final last = _userId == null ? null : preferences.getInt(_syncKey);
      if (!force &&
          last != null &&
          preferences.getString(_ownerKey) == _userId &&
          preferences.getString('$_syncKey.zone') == zone &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
              const Duration(days: 7)) {
        _publish(
          state.copyWith(
            registrationStatus: ReminderRegistrationStatus.registered,
            clearError: true,
          ),
        );
        return true;
      }
      _publish(
        state.copyWith(
          registrationStatus: ReminderRegistrationStatus.registering,
          clearError: true,
        ),
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final currentToken =
              token ??
              await _messaging.getToken().timeout(const Duration(seconds: 10));
          if (!_active) return false;
          if (currentToken == null || currentToken.trim().isEmpty) {
            throw const _EmptyTokenException();
          }
          await _repository
              .registerInstallation(
                installationId: _installationId!,
                token: currentToken,
                platform: kIsWeb ? 'web' : 'android',
                timeZone: zone,
              )
              .timeout(const Duration(seconds: 10));
          if (!_active) return false;
          if (_userId != null) {
            await preferences.setInt(
              _syncKey,
              DateTime.now().millisecondsSinceEpoch,
            );
            await preferences.setString('$_syncKey.zone', zone);
            await preferences.setString(_ownerKey, _userId);
          }
          if (!_active) return false;
          _publish(
            state.copyWith(
              registrationStatus: ReminderRegistrationStatus.registered,
              clearError: true,
            ),
          );
          return true;
        } catch (error) {
          if (!_active) return false;
          _diagnose(error);
          if (attempt == 2 || !_transient(error)) rethrow;
          await _delay(Duration(seconds: attempt + 1));
          if (!_active) return false;
        }
      }
      return false;
    } catch (error) {
      if (_active) {
        _publish(
          state.copyWith(
            registrationStatus: ReminderRegistrationStatus.failed,
            errorMessage: _message(error),
          ),
        );
      }
      return false;
    }
  }

  Future<void> unregisterBeforeLogout() async {
    if (!_isAuthenticated) return;
    _loggingOut = true;
    await _syncInFlight;
    final preferences = await SharedPreferences.getInstance();
    if (_installationId != null) {
      try {
        await _repository
            .removeInstallation(_installationId!)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        /* Logout remains available offline. */
      }
      await preferences.remove(_syncKey);
      await preferences.remove('$_syncKey.zone');
      if (preferences.getString(_ownerKey) == _userId) {
        await preferences.remove(_ownerKey);
      }
    }
    await preferences.remove('notifications.lastInstallationSyncAt');
    await preferences.remove('notifications.lastTimeZone');
  }

  bool _transient(Object error) {
    if (error is _EmptyTokenException || error is TimeoutException) return true;
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      final text = (error.message ?? '').toLowerCase();
      if (text.contains('authentication_failed') ||
          text.contains('invalid_api_key') ||
          text.contains('403')) {
        return false;
      }
      return code == 'unknown' ||
          code == 'unavailable' ||
          code == 'network-request-failed' ||
          text.contains('service_not_available');
    }
    return false;
  }

  void _diagnose(Object error) {
    final code = error is FirebaseException
        ? error.code
        : error is PlatformException
        ? error.code
        : error.runtimeType.toString();
    // Omit exception text, token, account identifiers and request URLs.
    developer.log(
      'Notification registration failed: $code',
      name: 'DailyReminderController',
    );
  }

  String _message(Object error) {
    _diagnose(error);
    if (error is PlatformException &&
        error.code == 'play_services_unavailable') {
      return 'Google Play services belum tersedia atau perlu diperbarui. Perbarui melalui Play Store lalu coba lagi.';
    }
    if (error is FirebaseException ||
        error is _EmptyTokenException ||
        error is TimeoutException) {
      return 'Perangkat belum berhasil terhubung ke layanan notifikasi. Periksa koneksi dan Google Play services, lalu coba lagi.';
    }
    return 'Pengaturan notifikasi belum dapat disimpan. Periksa koneksi lalu coba lagi.';
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
    _publish(state.copyWith(clearPendingTap: true));
  }

  void _handleMessageTap(RemoteMessage message) {
    if (!_active) return;
    final String route = _safeRoute(message.data['route']?.toString());
    _publish(
      state.copyWith(
        pendingTap: ReminderNotificationTap(
          route: route,
          deliveryId: message.data['deliveryId']?.toString(),
        ),
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

  @override
  void dispose() {
    unawaited(_tokenSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    super.dispose();
  }
}

class _EmptyTokenException implements Exception {
  const _EmptyTokenException();
}
