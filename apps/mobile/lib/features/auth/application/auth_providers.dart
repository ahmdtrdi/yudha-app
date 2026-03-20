import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false; // Initially unauthenticated
  }

  void login(String email, String password) {
    // Mock login logic
    state = true;
  }

  void signUp(String email, String password, String name, dynamic target) {
    // Mock sign up logic
    state = true;
  }

  void logout() {
    state = false;
  }
}

final authProvider = NotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});
