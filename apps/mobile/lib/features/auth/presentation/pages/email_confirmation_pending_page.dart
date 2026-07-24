import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';

class EmailConfirmationPendingPage extends ConsumerStatefulWidget {
  const EmailConfirmationPendingPage({super.key, this.email});

  final String? email;

  @override
  ConsumerState<EmailConfirmationPendingPage> createState() =>
      _EmailConfirmationPendingPageState();
}

class _EmailConfirmationPendingPageState
    extends ConsumerState<EmailConfirmationPendingPage> {
  bool _isResending = false;
  String? _statusMessage;
  bool _isStatusError = false;

  Future<void> _resendConfirmationEmail() async {
    final String? normalizedEmail = _normalizedEmail;
    if (normalizedEmail == null || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    final String? error = await ref
        .read(authProvider.notifier)
        .resendConfirmationEmail(normalizedEmail);

    if (!mounted) {
      return;
    }

    setState(() {
      _isResending = false;
      _statusMessage = error ??
          'Email verifikasi baru sudah dikirim. Silakan cek inbox dan folder spam.';
      _isStatusError = error != null;
    });
  }

  String? get _normalizedEmail {
    final String? email = widget.email;
    if (email == null) {
      return null;
    }
    final String trimmed = email.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final String? normalizedEmail = _normalizedEmail;

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.warriorNavy.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: 68,
                      height: 68,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.levelUpTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: AppColors.levelUpTeal,
                        size: 32,
                      ),
                    ),
                    Text(
                      'Verifikasi Email Diperlukan',
                      style: GoogleFonts.fredoka(
                        color: AppColors.warriorNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      normalizedEmail == null
                          ? 'Akun kamu sudah berhasil dibuat. Sekarang buka inbox email kamu, lalu klik tautan verifikasi sebelum masuk ke aplikasi.'
                          : 'Akun untuk $normalizedEmail sudah berhasil dibuat. Sekarang buka inbox email itu, lalu klik tautan verifikasi sebelum masuk ke aplikasi.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_statusMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isStatusError
                              ? const Color(0xFFD92D20).withValues(alpha: 0.08)
                              : AppColors.levelUpTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isStatusError
                                ? const Color(0xFFD92D20).withValues(alpha: 0.2)
                                : AppColors.levelUpTeal.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.dmSans(
                            color: AppColors.textStrong,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.fireGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Kalau email belum terlihat, cek folder spam atau promo. Setelah email berhasil diverifikasi, kembali ke halaman masuk untuk melanjutkan.',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: normalizedEmail == null || _isResending
                            ? null
                            : _resendConfirmationEmail,
                        icon: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(
                                Icons.mark_email_read_outlined,
                                size: 18,
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warriorNavy,
                          side: BorderSide(
                            color: AppColors.warriorNavy.withValues(alpha: 0.18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        label: Text(
                          _isResending
                              ? 'Mengirim Ulang...'
                              : 'Kirim Ulang Email Verifikasi',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => context.go(AppRoutes.login),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warriorNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Kembali ke Halaman Masuk',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
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
