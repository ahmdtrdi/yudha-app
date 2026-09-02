import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/core/errors/user_facing_error.dart';
import 'package:yudha_mobile/features/auth/data/app_auth_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class AppAuthState {
  const AppAuthState({
    required this.isConfigured,
    required this.isLoading,
    this.session,
    this.errorMessage,
    this.errorCode,
  });

  factory AppAuthState.initial() {
    return AppAuthState(
      isConfigured: AppConfig.hasSupabaseConfig,
      isLoading: false,
      session: AppConfig.hasSupabaseConfig
          ? Supabase.instance.client.auth.currentSession
          : null,
    );
  }

  final bool isConfigured;
  final bool isLoading;
  final Session? session;
  final String? errorMessage;
  final String? errorCode;

  bool get isAuthenticated => session != null;

  String? get accessToken => session?.accessToken;

  AppAuthState copyWith({
    bool? isLoading,
    Session? session,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AppAuthState(
      isConfigured: isConfigured,
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : session ?? this.session,
      errorMessage: clearError && errorMessage == null
          ? null
          : errorMessage ?? this.errorMessage,
      errorCode: clearError && errorCode == null
          ? null
          : errorCode ?? this.errorCode,
    );
  }
}

class AuthNotifier extends Notifier<AppAuthState> {
  SupabaseClient? get _client =>
      AppConfig.hasSupabaseConfig ? Supabase.instance.client : null;

  @override
  AppAuthState build() {
    final AppAuthState initialState = AppAuthState.initial();
    final SupabaseClient? client = _client;
    if (client != null) {
      final subscription = client.auth.onAuthStateChange.listen((
        AuthState event,
      ) {
        state = state.copyWith(
          isLoading: false,
          session: event.session,
          clearSession: event.session == null,
          clearError: true,
        );
      });
      ref.onDispose(subscription.cancel);
    }
    return initialState;
  }

  Future<bool> login(String email, String password) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      state = state.copyWith(
        errorMessage: 'Layanan akun belum dikonfigurasi pada aplikasi ini.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final Session? session = response.session;
      if (session != null) {
        await _persistSession(session);
      }
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
      );
      return session != null;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _describeAuthException(error, action: 'masuk'),
        errorCode: _extractAuthErrorCode(error),
      );
      return false;
    } catch (error, stackTrace) {
      log(
        'Unexpected login error',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: _describeUnexpectedError(error, action: 'masuk'),
      );
      return false;
    }
  }

  Future<bool> signUp(
    String email,
    String password,
    String name,
    ProfileTarget? target,
  ) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      state = state.copyWith(
        errorMessage: 'Layanan akun belum dikonfigurasi pada aplikasi ini.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final AuthResponse response = await client.auth.signUp(
        email: email,
        password: password,
        data: <String, Object?>{
          'display_name': name.trim(),
          'target': target?.name,
        },
      );
      if (response.user != null && response.session == null) {
        state = state.copyWith(
          isLoading: false,
          clearSession: true,
          clearError: true,
          errorCode: 'email_confirmation_pending',
        );
        return false;
      }

      final Session? session = response.session;
      if (session != null) {
        await _persistSession(session);
      }
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
      );
      return session != null;
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _describeAuthException(error, action: 'daftar'),
        errorCode: _extractAuthErrorCode(error),
      );
      return false;
    } catch (error, stackTrace) {
      log(
        'Unexpected signup error',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: _describeUnexpectedError(error, action: 'daftar'),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final SupabaseClient? client = _client;
    if (client != null) {
      await client.auth.signOut();
      await _clearPersistedSession();
    }
    state = state.copyWith(clearSession: true, clearError: true);
  }

  Future<void> clearDeletedAccountSession() async {
    final SupabaseClient? client = _client;
    if (client != null) {
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // The server-side user no longer exists; local cleanup must still run.
      }
      await _clearPersistedSession();
    }
    state = state.copyWith(clearSession: true, clearError: true);
  }

  Future<String?> resendConfirmationEmail(String email) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return 'Layanan akun belum dikonfigurasi pada aplikasi ini.';
    }

    try {
      await client.auth.resend(type: OtpType.signup, email: email.trim());
      return null;
    } on AuthException catch (error) {
      return _describeAuthException(
        error,
        action: 'kirim ulang email verifikasi',
      );
    } catch (error, stackTrace) {
      log(
        'Unexpected resend confirmation error',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      return _describeUnexpectedError(
        error,
        action: 'kirim ulang email verifikasi',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _persistSession(Session session) async {
    try {
      await AppAuthStorage.instance.persistSession(
        jsonEncode(session.toJson()),
      );
    } catch (error, stackTrace) {
      log(
        'Could not persist auth session',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      await AppAuthStorage.instance.removePersistedSession();
    } catch (error, stackTrace) {
      log(
        'Could not clear persisted auth session',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _describeUnexpectedError(Object error, {required String action}) {
    return UserFacingError.describe(
      error,
      fallback: 'Gagal $action. Coba lagi beberapa saat.',
    );
  }

  String _describeAuthException(AuthException error, {required String action}) {
    final String normalized = error.message.trim().toLowerCase();
    final String? code = _extractAuthErrorCode(error);

    if (code == 'invalid_login_credentials' ||
        normalized.contains('invalid login credential') ||
        normalized.contains('invalid login credentials')) {
      return 'Email atau password tidak valid.';
    }

    if (code == 'email_not_confirmed' ||
        normalized.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox email kamu lalu klik tautan verifikasi sebelum masuk.';
    }

    if (code == 'over_email_send_rate_limit' ||
        normalized.contains('email rate limit')) {
      return 'Batas pengiriman email verifikasi sudah tercapai. Tunggu beberapa saat, lalu coba kirim ulang.';
    }

    if (code == 'over_request_rate_limit' ||
        error.statusCode == '429' ||
        normalized.contains('for security purposes')) {
      return 'Terlalu banyak percobaan dalam waktu singkat. Tunggu beberapa saat, lalu coba lagi.';
    }

    if (code == 'user_already_exists' ||
        normalized.contains('user already registered') ||
        normalized.contains('user already exists')) {
      return 'Email ini sudah terdaftar. Silakan masuk atau gunakan email lain.';
    }

    if (code == 'email_provider_disabled' ||
        normalized.contains('email provider is disabled')) {
      return 'Pendaftaran dengan email sedang dinonaktifkan.';
    }

    return _describeUnexpectedError(error, action: action);
  }

  String? _extractAuthErrorCode(AuthException error) {
    final String? explicitCode = error.code?.trim().toLowerCase();
    if (explicitCode != null && explicitCode.isNotEmpty) {
      return explicitCode;
    }

    final String raw = error.toString().toLowerCase();

    if (raw.contains('email_not_confirmed')) {
      return 'email_not_confirmed';
    }
    if (raw.contains('invalid login credential') ||
        raw.contains('invalid login credentials')) {
      return 'invalid_login_credentials';
    }
    return null;
  }
}

final NotifierProvider<AuthNotifier, AppAuthState> authProvider =
    NotifierProvider<AuthNotifier, AppAuthState>(() => AuthNotifier());

final Provider<bool> isAuthenticatedProvider = Provider<bool>(
  (Ref ref) => ref.watch(authProvider).isAuthenticated,
);

final Provider<String?> authAccessTokenProvider = Provider<String?>(
  (Ref ref) => ref.watch(authProvider).accessToken,
);
