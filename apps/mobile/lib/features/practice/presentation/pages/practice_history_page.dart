import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/practice/application/practice_history_state.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/presentation/widgets/practice_activity_tile.dart';

class PracticeHistoryPage extends ConsumerWidget {
  const PracticeHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PracticeHistoryState state = ref.watch(
      practiceHistoryControllerProvider,
    );
    final controller = ref.read(practiceHistoryControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        foregroundColor: Colors.white,
        title: Text(
          'RIWAYAT LATIHAN',
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: switch (state.status) {
        PracticeHistoryViewStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PracticeHistoryViewStatus.error => _HistoryMessage(
          icon: Icons.cloud_off_rounded,
          message: state.errorMessage ?? 'Gagal memuat riwayat latihan.',
          actionLabel: 'Coba lagi',
          onAction: controller.loadInitial,
        ),
        PracticeHistoryViewStatus.empty => _HistoryMessage(
          icon: Icons.history_rounded,
          message: 'Belum ada riwayat latihan.',
          actionLabel: null,
          onAction: null,
        ),
        PracticeHistoryViewStatus.success => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            itemCount: state.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              if (index < state.items.length) {
                final PracticeRecentActivity activity = state.items[index];
                return PracticeActivityTile(activity: activity);
              }
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: state.isLoadingMore
                      ? const Center(child: CircularProgressIndicator())
                      : state.hasMore
                      ? TextButton(
                          onPressed: controller.loadMore,
                          child: const Text('Muat lebih banyak'),
                        )
                      : const SizedBox(height: 16),
                ),
              );
            },
          ),
        ),
      },
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
