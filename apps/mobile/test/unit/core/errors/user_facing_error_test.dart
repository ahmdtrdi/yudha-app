import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/core/errors/user_facing_error.dart';

void main() {
  group('UserFacingError', () {
    test('hides infrastructure details for offline failures', () {
      final SocketException error = const SocketException(
        'Failed host lookup: api.example.test',
      );

      expect(
        UserFacingError.describe(error, fallback: 'Gagal memuat data.'),
        UserFacingError.offlineMessage,
      );
      expect(
        UserFacingError.describe(
          Exception('ClientException: XMLHttpRequest error.'),
          fallback: 'Gagal memuat data.',
        ),
        UserFacingError.offlineMessage,
      );
      expect(
        UserFacingError.describe(
          Exception('Connection timed out while opening websocket'),
          fallback: 'Gagal memuat data.',
        ),
        UserFacingError.offlineMessage,
      );
    });

    test('uses the feature fallback for an unexpected internal error', () {
      expect(
        UserFacingError.describe(
          Exception('Supabase internal detail'),
          fallback: 'Gagal masuk. Coba lagi.',
        ),
        'Gagal masuk. Coba lagi.',
      );
    });

    test('can preserve safe API details for non-network failures', () {
      expect(
        UserFacingError.describe(
          Exception('Y-Coin belum cukup.'),
          fallback: 'Transaksi gagal.',
          preserveDetails: true,
        ),
        'Y-Coin belum cukup.',
      );
    });
  });
}
