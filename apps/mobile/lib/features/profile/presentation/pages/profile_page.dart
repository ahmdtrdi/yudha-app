import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_language.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerProgress progress = ref.watch(playerProgressProvider);
    final profileSettings = ref.watch(profileSettingsProvider);
    final settingsController = ref.read(profileSettingsProvider.notifier);

    final int winRatePercent = (progress.winRate * 100).round();
    final String trendLabel = switch (progress.lastDelta) {
      > 0 => 'Naik +${progress.lastDelta}',
      < 0 => 'Turun ${progress.lastDelta}',
      _ => 'Stabil',
    };
    final Color trendColor = switch (progress.lastDelta) {
      > 0 => AppColors.levelUpTeal,
      < 0 => AppColors.fireGold,
      _ => AppColors.textMuted,
    };
    final IconData trendIcon = switch (progress.lastDelta) {
      > 0 => Icons.trending_up,
      < 0 => Icons.trending_down,
      _ => Icons.trending_flat,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Personal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _ProfileHeaderCard(progress: progress),
          const SizedBox(height: 12),
          _SectionTitle(
            icon: Icons.bar_chart_rounded,
            title: 'Analisis Performa',
          ),
          const SizedBox(height: 8),
          _MetricGrid(
            children: <Widget>[
              _MetricCard(label: 'Winrate', value: '$winRatePercent%'),
              _MetricCard(label: 'Tier', value: progress.tier.label),
              _MetricCard(label: 'Match', value: '${progress.matchesPlayed}'),
              _MetricCard(
                label: 'Best Streak',
                value: '${progress.bestStreak}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warriorNavy.withAlpha(35)),
            ),
            child: Row(
              children: <Widget>[
                Icon(trendIcon, color: trendColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trend Rank (simulasi): $trendLabel',
                    style: TextStyle(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(icon: Icons.tune_rounded, title: 'Pengaturan Profil'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warriorNavy.withAlpha(35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Bahasa',
                  style: TextStyle(
                    color: AppColors.warriorNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ProfileLanguage>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<ProfileLanguage>>[
                    ButtonSegment<ProfileLanguage>(
                      value: ProfileLanguage.id,
                      label: Text('ID'),
                    ),
                    ButtonSegment<ProfileLanguage>(
                      value: ProfileLanguage.en,
                      label: Text('EN'),
                    ),
                  ],
                  selected: <ProfileLanguage>{profileSettings.language},
                  onSelectionChanged: (Set<ProfileLanguage> selected) {
                    settingsController.setLanguage(selected.first);
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Bahasa aktif: ${profileSettings.language.label}',
                  key: const Key('active-language-label'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifikasi Harian'),
                  value: profileSettings.notificationsEnabled,
                  onChanged: settingsController.toggleNotifications,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Suara Efek'),
                  value: profileSettings.soundEnabled,
                  onChanged: settingsController.toggleSound,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Haptic Feedback'),
                  value: profileSettings.hapticsEnabled,
                  onChanged: settingsController.toggleHaptics,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final String avatarInitial = progress.displayName.isEmpty
        ? '?'
        : progress.displayName.substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.warriorNavy, Color(0xFF0E4AAE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.scholarCream.withAlpha(40),
            child: Text(
              avatarInitial,
              style: const TextStyle(
                color: AppColors.scholarCream,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  progress.displayName,
                  style: const TextStyle(
                    color: AppColors.scholarCream,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${progress.tier.label} Tier',
                  style: TextStyle(
                    color: AppColors.scholarCream.withAlpha(220),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Poin total: ${progress.totalPoints}',
                  style: TextStyle(
                    color: AppColors.scholarCream.withAlpha(220),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ganti avatar',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Avatar customization coming soon'),
                ),
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.scholarCream,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.warriorNavy, size: 20),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: children,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.warriorNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
