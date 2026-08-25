import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/notifications/application/daily_reminder_providers.dart';

Future<void> maybeShowNotificationPermissionPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(dailyReminderProvider.notifier);
  if (!await controller.claimFirstSuccessPrompt() || !context.mounted) return;

  final bool enable =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Jaga ritme belajarmu'),
          content: const Text(
            'Aktifkan pengingat misi pagi dan penyelamat streak. Waktunya bisa kamu ubah dari Profil.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Nanti'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Aktifkan'),
            ),
          ],
        ),
      ) ??
      false;
  if (enable) await controller.requestPermissionAndEnable();
}
