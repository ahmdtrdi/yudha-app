import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/auth_input_validators.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileOnboardingPage extends ConsumerStatefulWidget {
  const ProfileOnboardingPage({super.key});

  @override
  ConsumerState<ProfileOnboardingPage> createState() =>
      _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends ConsumerState<ProfileOnboardingPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  ProfileTarget? _selectedTarget;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _nameError;
  String? _targetError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ref.read(authProvider).isAuthenticated) {
        context.go(AppRoutes.lobby);
        return;
      }
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String name = _nameController.text.trim();
    final ProfileTarget? target = _selectedTarget;

    setState(() {
      _emailError = AuthInputValidators.validateEmail(email);
      _passwordError = AuthInputValidators.validatePassword(password);
      _nameError = name.isEmpty ? 'Nama wajib diisi.' : null;
      _targetError = target == null ? 'Pilih target belajar.' : null;
    });

    if (_emailError != null ||
        _passwordError != null ||
        _nameError != null ||
        _targetError != null ||
        target == null) {
      return;
    }

    final bool didSignUp = await ref
        .read(authProvider.notifier)
        .signUp(email, password, name, target);
    if (!mounted) {
      return;
    }

    final AppAuthState authState = ref.read(authProvider);
    if (!didSignUp && authState.errorCode == 'email_confirmation_pending') {
      context.go(AppRoutes.confirmEmail, extra: email);
      return;
    }

    if (!didSignUp) {
      final String message =
          authState.errorMessage ??
          'Pendaftaran belum berhasil. Periksa kembali data yang kamu isi.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      return;
    }

    ref
        .read(profileSettingsProvider.notifier)
        .completeProfile(displayName: name, target: target);
    ref.read(playerProgressProvider.notifier).setDisplayName(name);

    context.go(AppRoutes.lobby);
  }

  InputDecoration _clayInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFBF9F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.dmSans(
        color: AppColors.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.dmSans(
        color: AppColors.textMuted.withAlpha(120),
        fontSize: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5DDD0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.warriorNavy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD94848), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD94848), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppAuthState authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE5DDD0),
                    width: 1.5,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0xFFE6DDD0),
                      offset: Offset(0, 6),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x0C000000),
                      offset: Offset(0, 10),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Mascot Brand Badge (Clay circular inset)
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF9F5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8E0D2),
                            width: 1.5,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0xFFE6DDD0),
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/branding/app-icon-new.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Text(
                      'Daftar Akun Baru',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: AppColors.warriorNavy,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Buat akun dan lengkapi profil sebelum masuk arena.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (authState.errorMessage != null) ...<Widget>[
                      _AuthErrorBanner(message: authState.errorMessage!),
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
                      decoration: _clayInputDecoration(
                        labelText: 'Email',
                        hintText: 'Masukkan email kamu',
                        prefixIcon: Icons.alternate_email_rounded,
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      decoration: _clayInputDecoration(
                        labelText: 'Password',
                        hintText: '********',
                        prefixIcon: Icons.lock_outline_rounded,
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() {
                            _nameError = null;
                          });
                        }
                      },
                      decoration: _clayInputDecoration(
                        labelText: 'Nama',
                        hintText: 'Contoh: Ahmad',
                        prefixIcon: Icons.person_outline_rounded,
                        errorText: _nameError,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Target belajar',
                      style: GoogleFonts.dmSans(
                        color: AppColors.warriorNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ProfileTarget>(
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<ProfileTarget>>[
                        ButtonSegment<ProfileTarget>(
                          value: ProfileTarget.cpns,
                          label: Text('CPNS'),
                        ),
                        ButtonSegment<ProfileTarget>(
                          value: ProfileTarget.bumn,
                          label: Text('BUMN'),
                        ),
                      ],
                      selected: _selectedTarget == null
                          ? const <ProfileTarget>{}
                          : <ProfileTarget>{_selectedTarget!},
                      onSelectionChanged: (Set<ProfileTarget> selected) {
                        setState(() {
                          _selectedTarget = selected.isEmpty
                              ? null
                              : selected.first;
                          _targetError = null;
                        });
                      },
                    ),
                    if (_targetError != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _targetError!,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFFB03030),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    // Tactile Clay Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: authState.isLoading
                            ? null
                            : const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0xFF071F52),
                                  offset: Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                      ),
                      child: FilledButton(
                        onPressed: authState.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warriorNavy,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: Color(0x33FFFFFF),
                              width: 1,
                            ),
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
                                'Daftar & Lanjut',
                                style: GoogleFonts.fredoka(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).clearError();
                        context.go(AppRoutes.login);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warriorNavy,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Sudah punya akun? Masuk',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD4D4), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFFF7DDDD),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD94848), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF7A2020),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
