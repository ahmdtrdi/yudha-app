import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class AppAuthState {
  const AppAuthState({
    required this.isConfigured,
    required this.isLoading,
    this.session,
    this.errorMessage,
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

  bool get isAuthenticated => session != null;

  String? get accessToken => session?.accessToken;

  AppAuthState copyWith({
    bool? isLoading,
    Session? session,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AppAuthState(
      isConfigured: isConfigured,
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
      client.auth.onAuthStateChange.listen((AuthState event) {
        state = state.copyWith(
          session: event.session,
          clearSession: event.session == null,
          clearError: true,
        );
      });
    }
    return initialState;
  }

  Future<bool> login(String email, String password) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      state = state.copyWith(
        errorMessage:
            'Supabase belum dikonfigurasi. Tambahkan SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, session: response.session);
      return response.session != null;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
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
        errorMessage:
            'Supabase belum dikonfigurasi. Tambahkan SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
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
      state = state.copyWith(isLoading: false, session: response.session);
      return response.user != null;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
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
    }
    state = state.copyWith(clearSession: true, clearError: true);
  }

  String _describeUnexpectedError(Object error, {required String action}) {
    final String raw = error.toString().trim();
    final String normalized = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;

    if (normalized.contains('Failed host lookup') ||
        normalized.contains('SocketException') ||
        normalized.contains('ClientException')) {
      return 'Tidak bisa terhubung ke layanan auth. Periksa koneksi internet dan konfigurasi Supabase.';
    }

    if (normalized.isEmpty) {
      return 'Gagal $action. Coba lagi beberapa saat.';
    }

    return normalized;
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
