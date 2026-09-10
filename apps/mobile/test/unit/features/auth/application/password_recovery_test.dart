import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/router/app_router.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/application/password_recovery_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = <String, dynamic>{
    'id': 'user-1',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'test@example.test',
    'created_at': '2026-09-11T00:00:00Z',
  };
  late SupabaseClient client;
  late ProviderContainer container;
  late List<http.Request> requests;
  var responseStatus = 200;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PasswordRecoveryContext.linkReceived = false;
    responseStatus = 200;
    requests = <http.Request>[];
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: AuthClientOptions(
        pkceAsyncStorage: SharedPreferencesGotrueAsyncStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (responseStatus != 200) {
          return http.Response(
            jsonEncode({
              'msg': 'rate limited',
              'code': 'over_email_send_rate_limit',
            }),
            responseStatus,
          );
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/user') ? user : <String, dynamic>{},
          ),
          200,
        );
      }),
    );
    container = ProviderContainer(
      overrides: [authClientProvider.overrideWithValue(client)],
    );
    container.read(authProvider);
  });
  tearDown(() async {
    container.dispose();
    await client.dispose();
    PasswordRecoveryContext.linkReceived = false;
  });

  Future<void> receiveRecovery() async {
    final token =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'user-1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
    await client.auth.getSessionFromUrl(
      Uri.parse(
        'com.yudha.app://reset-callback/#access_token=$token&refresh_token=test-refresh&expires_in=3600&token_type=bearer&type=recovery',
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('reset request uses email and Android callback', () async {
    expect(
      await container
          .read(authProvider.notifier)
          .requestPasswordReset(' test@example.test '),
      isNull,
    );
    expect(requests.single.url.path, '/auth/v1/recover');
    expect(
      requests.single.url.queryParameters['redirect_to'],
      'com.yudha.app://reset-callback/',
    );
    expect(jsonDecode(requests.single.body)['email'], 'test@example.test');
  });
  test('rate limits receive Indonesian feedback', () async {
    responseStatus = 429;
    expect(
      await container
          .read(authProvider.notifier)
          .requestPasswordReset('test@example.test'),
      contains('Terlalu banyak'),
    );
  });
  test('URL recognition alone cannot authorize a password update', () async {
    PasswordRecoveryContext.detectAuthCallback(
      Uri.parse('com.yudha.app://reset-callback/?error=access_denied'),
    );
    expect(
      await container
          .read(authProvider.notifier)
          .updateRecoveredPassword('new-secret'),
      isFalse,
    );
    expect(requests, isEmpty);
  });
  test('validated recovery event overrides normal lobby navigation', () async {
    await receiveRecovery();
    final state = container.read(authProvider);
    expect(state.isRecoveryVerified, isTrue);
    expect(
      appRedirect(
        isAuthenticated: true,
        isPasswordRecovery: state.isPasswordRecovery,
        uri: Uri.parse('/login'),
      ),
      '/reset-password',
    );
    expect(
      appRedirect(
        isAuthenticated: true,
        isPasswordRecovery: true,
        uri: Uri.parse('/'),
      ),
      '/reset-password',
    );
    expect(
      appRedirect(
        isAuthenticated: true,
        isPasswordRecovery: true,
        uri: Uri.parse('/reset-password'),
      ),
      isNull,
    );
  });
  test('successful update clears recovery and session', () async {
    await receiveRecovery();
    expect(
      await container
          .read(authProvider.notifier)
          .updateRecoveredPassword('new-secret'),
      isTrue,
    );
    expect(
      requests.any(
        (r) =>
            r.method == 'PUT' && jsonDecode(r.body)['password'] == 'new-secret',
      ),
      isTrue,
    );
    expect(container.read(authProvider).session, isNull);
    expect(container.read(authProvider).isRecoveryVerified, isFalse);
    expect(container.read(authProvider).isPasswordRecovery, isFalse);
  });
  test(
    'cold-start callback event is replayed to a new auth listener',
    () async {
      container.dispose();
      await receiveRecovery();
      container = ProviderContainer(
        overrides: [authClientProvider.overrideWithValue(client)],
      );
      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).isRecoveryVerified, isTrue);
    },
  );
  test('ordinary login retains its existing destination', () {
    expect(appRedirect(isAuthenticated: true, uri: Uri.parse('/login')), '/');
    expect(
      appRedirect(isAuthenticated: false, uri: Uri.parse('/forgot-password')),
      isNull,
    );
  });
  test(
    'normal web navigation under the callback path does not enter recovery',
    () {
      expect(
        PasswordRecoveryContext.detectAuthCallback(
          Uri.parse('https://example.test/reset-password#/login'),
        ),
        isFalse,
      );
      expect(PasswordRecoveryContext.linkReceived, isFalse);
    },
  );
  test('web code and expired-link callbacks enter recovery handling', () {
    expect(
      PasswordRecoveryContext.detectAuthCallback(
        Uri.parse('https://example.test/reset-password?code=test-code'),
      ),
      isTrue,
    );
    expect(PasswordRecoveryContext.linkReceived, isTrue);
    PasswordRecoveryContext.linkReceived = false;
    expect(
      PasswordRecoveryContext.detectAuthCallback(
        Uri.parse('com.yudha.app://reset-callback/?error=access_denied'),
      ),
      isTrue,
    );
    expect(PasswordRecoveryContext.linkReceived, isTrue);
  });
}
