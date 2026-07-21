import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';

void main() {
  group('AppAuthState.copyWith', () {
    test(
      'keeps a replacement error code while clearing the previous error',
      () {
        const AppAuthState initial = AppAuthState(
          isConfigured: true,
          isLoading: true,
          errorMessage: 'Kesalahan lama',
          errorCode: 'old_error',
        );

        final AppAuthState next = initial.copyWith(
          isLoading: false,
          clearError: true,
          errorCode: 'email_confirmation_pending',
        );

        expect(next.isLoading, isFalse);
        expect(next.errorMessage, isNull);
        expect(next.errorCode, 'email_confirmation_pending');
      },
    );

    test('clears both error fields when no replacement is supplied', () {
      const AppAuthState initial = AppAuthState(
        isConfigured: true,
        isLoading: false,
        errorMessage: 'Kesalahan lama',
        errorCode: 'old_error',
      );

      final AppAuthState next = initial.copyWith(clearError: true);

      expect(next.errorMessage, isNull);
      expect(next.errorCode, isNull);
    });
  });
}
