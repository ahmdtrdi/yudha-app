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
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.levelUpTeal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.levelUpTeal.withValues(alpha: 0.25),
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
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: AppColors.levelUpTeal,
                          size: 32,
                        ),
                      ),
                    ),
                    Text(
                      'Verifikasi Email Diperlukan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: AppColors.warriorNavy,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      normalizedEmail == null
                          ? 'Akun kamu sudah berhasil dibuat. Sekarang buka inbox email kamu, lalu klik tautan verifikasi sebelum masuk ke aplikasi.'
                          : 'Akun untuk $normalizedEmail sudah berhasil dibuat. Sekarang buka inbox email itu, lalu klik tautan verifikasi sebelum masuk ke aplikasi.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_statusMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isStatusError
                              ? const Color(0xFFFFF1F1)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isStatusError
                                ? const Color(0xFFFFD4D4)
                                : const Color(0xFFDCFCE7),
                            width: 1.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _isStatusError
                                  ? const Color(0xFFF7DDDD)
                                  : const Color(0xFFD4EED8),
                              offset: const Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.dmSans(
                            color: _isStatusError
                                ? const Color(0xFF7A2020)
                                : const Color(0xFF166534),
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
                        color: const Color(0xFFFFF9EE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFE8C2),
                          width: 1.5,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0xFFF5DFC0),
                            offset: Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'Kalau email belum terlihat, cek folder spam atau promo. Setelah email berhasil diverifikasi, kembali ke halaman masuk untuk melanjutkan.',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF6B4710),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          side: const BorderSide(
                            color: Color(0xFFE5DDD0),
                            width: 1.5,
                          ),
                          backgroundColor: const Color(0xFFFBF9F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: Text(
                          _isResending
                              ? 'Mengirim Ulang...'
                              : 'Kirim Ulang Email Verifikasi',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 52,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0xFF071F52),
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () => context.go(AppRoutes.login),
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
                        child: Text(
                          'Kembali ke Halaman Masuk',
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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
