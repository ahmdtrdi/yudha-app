import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

Future<bool?> showDummyPaymentConfirmation({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String priceLabel,
  String badgeText = 'BETA ACCESS AVAILABLE',
  IconData icon = Icons.payments_rounded,
  Color themeColor = AppColors.levelUpTeal,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _DummyPaymentConfirmationSheet(
      title: title,
      subtitle: subtitle,
      priceLabel: priceLabel,
      badgeText: badgeText,
      icon: icon,
      themeColor: themeColor,
    ),
  );
}

class _DummyPaymentConfirmationSheet extends StatefulWidget {
  const _DummyPaymentConfirmationSheet({
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.badgeText,
    required this.icon,
    required this.themeColor,
  });

  final String title;
  final String subtitle;
  final String priceLabel;
  final String badgeText;
  final IconData icon;
  final Color themeColor;

  @override
  State<_DummyPaymentConfirmationSheet> createState() =>
      __DummyPaymentConfirmationSheetState();
}

class __DummyPaymentConfirmationSheetState
    extends State<_DummyPaymentConfirmationSheet> {
  String _selectedMethod = 'qris';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = const <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'qris',
      'name': 'QRIS Instant Sandbox',
      'description': 'Scan QR dari e-Wallet / Mobile Banking (Dummy)',
      'icon': Icons.qr_code_scanner_rounded,
      'badge': 'POPULER',
    },
    <String, dynamic>{
      'id': 'yudha_wallet',
      'name': 'Yudha Pay (Beta)',
      'description': 'Saldo Sandbox: Rp500.000',
      'icon': Icons.account_balance_wallet_rounded,
      'badge': 'BEBAS BIAYA',
    },
    <String, dynamic>{
      'id': 'google_play',
      'name': 'Google Play Billing Sandbox',
      'description': 'Simulasi in-app purchase resmi Google Play',
      'icon': Icons.play_arrow_rounded,
      'badge': null,
    },
    <String, dynamic>{
      'id': 'va_bank',
      'name': 'Virtual Account Bank',
      'description': 'BCA, Mandiri, BNI, BRI (Nomor VA otomatis)',
      'icon': Icons.account_balance_rounded,
      'badge': null,
    },
  ];

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const ValueKey<String>('dummy-payment-confirmation-modal'),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top drag indicator bar
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.warriorNavy.withAlpha(40),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Modal Title & Header Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.themeColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.themeColor.withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Konfirmasi Pembayaran',
                                style: GoogleFonts.fredoka(
                                  color: AppColors.textStrong,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Simulasi Pembayaran (Sandbox)',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD77B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.science_rounded,
                          size: 13,
                          color: Color(0xFF865710),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SANDBOX',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF6E4B12),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Item Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.warriorNavy.withAlpha(20),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.dmSans(
                              color: AppColors.textStrong,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withAlpha(24),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: widget.themeColor.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            widget.badgeText,
                            style: GoogleFonts.dmSans(
                              color: widget.themeColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Harga Paket',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.priceLabel,
                          style: GoogleFonts.jetBrainsMono(
                            color: AppColors.textStrong,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Payment Method Selection Header
              Text(
                'Metode Pembayaran (Dummy)',
                style: GoogleFonts.fredoka(
                  color: AppColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              // Method Options List
              Column(
                children: _paymentMethods.map((Map<String, dynamic> method) {
                  final bool isSelected = _selectedMethod == method['id'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected ? Colors.white : const Color(0xFFF0ECF6),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMethod = method['id'] as String;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? widget.themeColor
                                  : AppColors.warriorNavy.withAlpha(20),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                method['icon'] as IconData,
                                color: isSelected
                                    ? widget.themeColor
                                    : AppColors.textMuted,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          method['name'] as String,
                                          style: GoogleFonts.dmSans(
                                            color: AppColors.textStrong,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (method['badge'] != null) ...<Widget>[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: widget.themeColor.withAlpha(25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              method['badge'] as String,
                                              style: GoogleFonts.dmSans(
                                                color: widget.themeColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      method['description'] as String,
                                      style: GoogleFonts.dmSans(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Radio<String>(
                                value: method['id'] as String,
                                groupValue: _selectedMethod,
                                activeColor: widget.themeColor,
                                onChanged: (String? val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedMethod = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Price Calculation & Total Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.themeColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.themeColor.withAlpha(40)),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Biaya Penanganan',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'GRATIS (Beta)',
                          style: GoogleFonts.dmSans(
                            color: AppColors.levelUpTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Total Pembayaran',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textStrong,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.priceLabel,
                          style: GoogleFonts.jetBrainsMono(
                            color: widget.themeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey<String>('confirm-dummy-payment-button'),
                      onPressed: _isProcessing ? null : _handleConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(Icons.lock_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Konfirmasi & Bayar',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
