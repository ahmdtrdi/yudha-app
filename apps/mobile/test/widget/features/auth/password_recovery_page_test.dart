import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/pages/password_recovery_page.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth({this.recovery = false});
  final bool recovery;
  int requests = 0;
  String? password;
  @override
  AppAuthState build() => AppAuthState(
    isConfigured: true,
    isLoading: false,
    isPasswordRecovery: recovery,
    isRecoveryVerified: recovery,
    session: recovery
        ? Session(
            accessToken: 'test',
            tokenType: 'bearer',
            user: User(
              id: 'test-user',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-09-11T00:00:00Z',
            ),
          )
        : null,
  );
  @override
  Future<String?> requestPasswordReset(String email) async {
    requests++;
    return null;
  }

  @override
  Future<bool> updateRecoveredPassword(String value) async {
    password = value;
    return true;
  }
}

void main() {
  testWidgets(
    'forgot form validates, confirms privately, and enforces resend cooldown',
    (tester) async {
      final auth = _FakeAuth();
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: PasswordRecoveryPage()),
        ),
      );
      await tester.tap(find.text('Kirim Tautan Reset'));
      await tester.pump();
      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(auth.requests, 0);
      await tester.enterText(find.byType(TextFormField), 'tester@example.test');
      await tester.tap(find.text('Kirim Tautan Reset'));
      await tester.pump();
      expect(auth.requests, 1);
      expect(
        find.textContaining('Jika email tersebut terdaftar'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 60));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'new password requires matching confirmation and returns to sign-in',
    (tester) async {
      final auth = _FakeAuth(recovery: true);
      final router = GoRouter(
        initialLocation: '/reset-password',
        routes: [
          GoRoute(
            path: '/reset-password',
            builder: (_, _) => const PasswordRecoveryPage(reset: true),
          ),
          GoRoute(
            path: '/login',
            builder: (_, state) =>
                Text(state.uri.queryParameters['passwordReset'] ?? 'login'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'new-secret');
      await tester.enterText(find.byType(TextFormField).at(1), 'different');
      await tester.tap(find.text('Simpan Password'));
      await tester.pump();
      expect(find.text('Konfirmasi password harus sama.'), findsOneWidget);
      expect(auth.password, isNull);
      await tester.enterText(find.byType(TextFormField).at(1), 'new-secret');
      await tester.tap(find.text('Simpan Password'));
      await tester.pumpAndSettle();
      expect(auth.password, 'new-secret');
      expect(find.text('success'), findsOneWidget);
    },
  );

  testWidgets(
    'invalid recovery link exposes a new-link action instead of a password form',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => _FakeAuth())],
          child: const MaterialApp(home: PasswordRecoveryPage(reset: true)),
        ),
      );
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Minta tautan baru'), findsOneWidget);
    },
  );
}
