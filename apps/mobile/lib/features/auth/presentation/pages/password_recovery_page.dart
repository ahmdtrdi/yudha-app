import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/auth_input_validators.dart';

class PasswordRecoveryPage extends ConsumerStatefulWidget {
  const PasswordRecoveryPage({super.key, this.reset = false, this.email});
  final bool reset;
  final String? email;

  @override
  ConsumerState<PasswordRecoveryPage> createState() =>
      _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends ConsumerState<PasswordRecoveryPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  bool _obscure = true;
  int _cooldown = 0;
  String? _error;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    if (widget.reset) {
      final success = await auth.updateRecoveredPassword(_password.text.trim());
      if (!mounted) return;
      if (success) {
        context.go('${AppRoutes.login}?passwordReset=success');
        return;
      }
      setState(() {
        _busy = false;
        _error =
            ref.read(authProvider).errorMessage ??
            'Tautan tidak valid. Minta tautan reset baru.';
      });
    } else {
      final error = await auth.requestPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
        _sent = error == null;
        _cooldown = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _cooldown--);
        if (_cooldown == 0) timer.cancel();
      });
    }
  }

  Future<void> _leave({bool requestAgain = false}) async {
    if (widget.reset) {
      await ref.read(authProvider.notifier).cancelPasswordRecovery();
    }
    if (mounted) {
      context.go(requestAgain ? AppRoutes.forgotPassword : AppRoutes.login);
    }
  }

  InputDecoration _decoration(String label, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFBF9F5),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final validRecovery =
        auth.isPasswordRecovery &&
        auth.isRecoveryVerified &&
        auth.session != null &&
        auth.errorCode != 'recovery_link_invalid';
    return PopScope(
      canPop: !widget.reset && !_busy,
      child: Scaffold(
        backgroundColor: AppColors.scholarCream,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5DDD0),
                      width: 1.5,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0xFFE6DDD0), offset: Offset(0, 6)),
                    ],
                  ),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Image.asset(
                          'assets/branding/app-icon-new.png',
                          height: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.reset ? 'Password Baru' : 'Lupa Password?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warriorNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.reset
                              ? 'Buat password baru untuk akun YUDHA kamu.'
                              : 'Masukkan email akunmu untuk menerima tautan reset password.',
                        ),
                        const SizedBox(height: 20),
                        if (widget.reset && !validRecovery) ...<Widget>[
                          Text(
                            auth.errorMessage ??
                                'Tautan reset belum terverifikasi atau sudah kedaluwarsa. Buka tautan dari email atau minta tautan baru.',
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _leave(requestAgain: true),
                            child: const Text('Minta tautan baru'),
                          ),
                        ] else ...<Widget>[
                          if (!widget.reset)
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              validator: (value) =>
                                  AuthInputValidators.validateEmail(
                                    value ?? '',
                                  ),
                              decoration: _decoration('Email'),
                            ),
                          if (widget.reset) ...<Widget>[
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autofillHints: const <String>[
                                AutofillHints.newPassword,
                              ],
                              validator: (value) =>
                                  AuthInputValidators.validatePassword(
                                    value ?? '',
                                  ),
                              decoration: _decoration(
                                'Password baru',
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirm,
                              enabled: !_busy,
                              obscureText: _obscure,
                              validator: (value) =>
                                  value == _password.text &&
                                      (value?.isNotEmpty ?? false)
                                  ? null
                                  : 'Konfirmasi password harus sama.',
                              decoration: _decoration(
                                'Konfirmasi password baru',
                              ),
                            ),
                          ],
                          if (_sent)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text(
                                'Jika email tersebut terdaftar, tautan reset akan dikirim. Periksa inbox dan folder spam.',
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy || _cooldown > 0 ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.warriorNavy,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Text(
                              _busy
                                  ? 'Memproses...'
                                  : widget.reset
                                  ? 'Simpan Password'
                                  : _cooldown > 0
                                  ? 'Kirim ulang dalam $_cooldown detik'
                                  : _sent
                                  ? 'Kirim Ulang'
                                  : 'Kirim Tautan Reset',
                            ),
                          ),
                        ],
                        TextButton(
                          onPressed: _busy ? null : () => _leave(),
                          child: const Text('Kembali ke Masuk'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
