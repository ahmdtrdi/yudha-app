import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/pages/email_confirmation_pending_page.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_onboarding_page.dart';

void main() {
  testWidgets('opens email confirmation page after a pending signup', (
    WidgetTester tester,
  ) async {
    await _pumpRegistrationFlow(
      tester,
      createAuthNotifier: _PendingConfirmationAuthNotifier.new,
    );

    await _submitValidRegistration(tester);

    expect(find.text('Verifikasi Email Diperlukan'), findsOneWidget);
    expect(find.textContaining('tester@example.com'), findsOneWidget);
    expect(find.text('Kembali ke Halaman Masuk'), findsOneWidget);
  });

  testWidgets('shows visible feedback when signup fails', (
    WidgetTester tester,
  ) async {
    await _pumpRegistrationFlow(
      tester,
      createAuthNotifier: _FailedAuthNotifier.new,
    );

    await _submitValidRegistration(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(_FailedAuthNotifier.message), findsWidgets);
    expect(find.text('Daftar Akun Baru'), findsOneWidget);
  });
}

Future<void> _pumpRegistrationFlow(
  WidgetTester tester, {
  required AuthNotifier Function() createAuthNotifier,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.profileSetup,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileOnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.confirmEmail,
        builder: (BuildContext context, GoRouterState state) =>
            EmailConfirmationPendingPage(
              email: state.extra is String ? state.extra as String : null,
            ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[authProvider.overrideWith(createAuthNotifier)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitValidRegistration(WidgetTester tester) async {
  final Finder fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'tester@example.com');
  await tester.enterText(fields.at(1), 'Password123!');
  await tester.enterText(fields.at(2), 'Tester');
  await tester.tap(find.text('CPNS'));
  await tester.pump();
  await tester.tap(find.text('Daftar & Lanjut'));
  await tester.pumpAndSettle();
}

class _PendingConfirmationAuthNotifier extends AuthNotifier {
  @override
  AppAuthState build() =>
      const AppAuthState(isConfigured: true, isLoading: false);

  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    ProfileTarget? target,
  ) async {
    state = state.copyWith(
      clearError: true,
      clearSession: true,
      errorCode: 'email_confirmation_pending',
    );
    return false;
  }
}

class _FailedAuthNotifier extends AuthNotifier {
  static const String message =
      'Terlalu banyak percobaan dalam waktu singkat. Tunggu beberapa saat, lalu coba lagi.';

  @override
  AppAuthState build() =>
      const AppAuthState(isConfigured: true, isLoading: false);

  @override
  Future<bool> signUp(
    String email,
    String password,
    String name,
    ProfileTarget? target,
  ) async {
    state = state.copyWith(
      errorMessage: message,
      errorCode: 'over_request_rate_limit',
    );
    return false;
  }
}
