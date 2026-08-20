import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/router/app_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';

void main() {
  test('all feature routes are private', () {
    for (final String path in <String>[
      AppRoutes.lobby,
      AppRoutes.pvp,
      AppRoutes.leaderboard,
      AppRoutes.practice,
      AppRoutes.practiceQuiz,
      AppRoutes.profile,
      AppRoutes.interviewSetup,
      AppRoutes.interview,
      AppRoutes.store,
      AppRoutes.hiredPass,
    ]) {
      expect(AppRoutes.isPrivate(Uri.parse(path)), isTrue, reason: path);
    }
  });

  test('public auth and onboarding routes stay public', () {
    for (final String path in AppRoutes.publicPaths) {
      expect(AppRoutes.isPrivate(Uri.parse(path)), isFalse, reason: path);
    }
  });

  test('login round-trip preserves a private path and query', () {
    final Uri destination = Uri.parse('/practice?category=twk');
    final Uri loginUri = Uri.parse(AppRoutes.loginFor(destination));

    expect(AppRoutes.postLoginDestination(loginUri), destination.toString());
  });

  test('unauthenticated private route redirects and resumes after login', () {
    final Uri destination = Uri.parse('/store?tab=towers');
    final String? login = appRedirect(isAuthenticated: false, uri: destination);
    expect(login, isNotNull);

    expect(
      appRedirect(isAuthenticated: true, uri: Uri.parse(login!)),
      destination.toString(),
    );
  });

  test('session loss redirects the current feature route to Login', () {
    final String? redirect = appRedirect(
      isAuthenticated: false,
      uri: Uri.parse(AppRoutes.interviewSetup),
    );

    expect(Uri.parse(redirect!).path, AppRoutes.login);
    expect(
      Uri.parse(redirect).queryParameters[AppRoutes.returnToQueryParameter],
      AppRoutes.interviewSetup,
    );
  });

  test('unsafe or public return destinations fall back to Lobby', () {
    for (final String destination in <String>[
      'https://example.com/store',
      '//example.com/store',
      AppRoutes.login,
      '/unknown',
    ]) {
      final Uri loginUri = Uri(
        path: AppRoutes.login,
        queryParameters: <String, String>{
          AppRoutes.returnToQueryParameter: destination,
        },
      );
      expect(AppRoutes.postLoginDestination(loginUri), AppRoutes.lobby);
    }
  });
}
