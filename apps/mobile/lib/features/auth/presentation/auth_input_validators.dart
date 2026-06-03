final RegExp _emailPattern = RegExp(
  r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
  caseSensitive: false,
);

abstract final class AuthInputValidators {
  static String? validateEmail(String value) {
    final String email = value.trim();
    if (email.isEmpty) {
      return 'Email wajib diisi.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Masukkan email yang valid.';
    }
    return null;
  }

  static String? validatePassword(String value) {
    final String password = value.trim();
    if (password.isEmpty) {
      return 'Password wajib diisi.';
    }
    if (password.length < 6) {
      return 'Password minimal 6 karakter.';
    }
    return null;
  }
}
