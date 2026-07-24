import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/onboarding/presentation/pages/splash_page.dart';

void main() {
  test('an authenticated session skips signup and opens the lobby', () {
    expect(splashDestination(isAuthenticated: true), AppRoutes.lobby);
  });

  test('a guest session opens login', () {
    expect(splashDestination(isAuthenticated: false), AppRoutes.login);
  });
}
