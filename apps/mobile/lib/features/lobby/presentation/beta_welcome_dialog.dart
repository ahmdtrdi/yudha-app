import 'package:flutter/material.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

class BetaWelcomeDialog extends StatefulWidget {
  const BetaWelcomeDialog({super.key, required this.acknowledge});
  final Future<void> Function() acknowledge;

  @override
  State<BetaWelcomeDialog> createState() => _BetaWelcomeDialogState();
}

class _BetaWelcomeDialogState extends State<BetaWelcomeDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.acknowledge();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Konfirmasi belum tersimpan. Bonusmu tetap aman. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: AppColors.scholarCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.celebration_rounded,
        color: AppColors.fireGold,
        size: 48,
      ),
      title: const Text('Bonus Beta Test'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Selamat datang di Beta Test YUDHA! Kamu mendapatkan bonus 1.000 koin dan 1.000 energi selama periode beta test.',
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: Text(_saving ? 'Menyimpan...' : 'Mulai Bermain'),
        ),
      ],
    ),
  );
}
