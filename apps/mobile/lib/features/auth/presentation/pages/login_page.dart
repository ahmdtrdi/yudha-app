import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/auth_input_validators.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _emailError = AuthInputValidators.validateEmail(email);
      _passwordError = AuthInputValidators.validatePassword(password);
    });

    if (_emailError != null || _passwordError != null) {
      return;
    }

    final bool didLogin = await ref
        .read(authProvider.notifier)
        .login(email, password);

    if (!mounted || !didLogin) {
      return;
    }

    context.go(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    final AppAuthState authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.warriorNavy.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat Datang',
                      style: GoogleFonts.orbitron(
                        color: AppColors.warriorNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk ke arena belajar YUDHA.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (authState.errorMessage != null) ...<Widget>[
                      _AuthErrorBanner(message: authState.errorMessage!),
                      if (authState.errorCode == 'email_not_confirmed') ...<Widget>[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              ref.read(authProvider.notifier).clearError();
                              context.go(
                                AppRoutes.confirmEmail,
                                extra: _emailController.text.trim(),
                              );
                            },
                            icon: const Icon(
                              Icons.mark_email_unread_outlined,
                              size: 18,
                            ),
                            label: const Text('Lihat langkah verifikasi email'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Masukkan email kamu',
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '********',
                        errorText: _passwordError,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: authState.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warriorNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Masuk',
                                style: GoogleFonts.orbitron(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).clearError();
                        context.go(AppRoutes.profileSetup);
                      },
                      child: Text(
                        'Belum punya akun? Daftar',
                        style: GoogleFonts.dmSans(
                          color: AppColors.warriorNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textStrong,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
