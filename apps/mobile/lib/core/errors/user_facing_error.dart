abstract final class UserFacingError {
  static const String offlineMessage =
      'Belum terhubung ke internet. Periksa koneksi lalu coba lagi.';

  static bool isNetworkFailure(Object error) {
    final String message = error.toString().toLowerCase();
    return <String>[
      'clientexception',
      'connection closed',
      'connection error',
      'connection refused',
      'connection reset',
      'connection timed out',
      'failed host lookup',
      'failed to connect',
      'fetch failed',
      'handshakeexception',
      'network is unreachable',
      'networkexception',
      'network request failed',
      'socketexception',
      'timed out',
      'xmlhttprequest error',
    ].any(message.contains);
  }

  static String describe(
    Object error, {
    required String fallback,
    bool preserveDetails = false,
  }) {
    if (isNetworkFailure(error)) {
      return offlineMessage;
    }

    if (!preserveDetails) {
      return fallback;
    }

    final String message = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '')
        .trim();
    return message.isEmpty ? fallback : message;
  }
}
