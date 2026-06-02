import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerProgress progress = ref.watch(playerProgressProvider);
    final profileSettings = ref.watch(profileSettingsProvider);
    final settingsController = ref.read(profileSettingsProvider.notifier);

    final int winRatePercent = (progress.winRate * 100).round();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Profil Personal',
          style: TextStyle(
            color: AppColors.warriorNavy,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          _ProfileHeaderCard(
            progress: progress,
            targetLabel: profileSettings.target?.label,
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            icon: Icons.bar_chart_rounded,
            title: 'Analisis Performa',
          ),
          const SizedBox(height: 10),
          _MetricGrid(
            children: <Widget>[
              _MetricCard(
                label: 'Winrate',
                value: '$winRatePercent%',
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.fireGold,
              ),
              _MetricCard(
                label: 'Tier',
                value: progress.tier.label,
                icon: Icons.shield_rounded,
                iconColor: AppColors.levelUpTeal,
              ),
              _MetricCard(
                label: 'Match',
                value: '${progress.matchesPlayed}',
                icon: Icons.sports_esports_rounded,
                iconColor: AppColors.warriorNavy,
              ),
              _MetricCard(
                label: 'Best Streak',
                value: '${progress.bestStreak}',
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.fireGold,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.tune_rounded,
            title: 'Pengaturan Profil',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.warriorNavy.withValues(alpha: 0.06),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.warriorNavy.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(
                      Icons.school_rounded,
                      color: AppColors.levelUpTeal,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Target Belajar',
                      style: TextStyle(
                        color: AppColors.textStrong,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ProfileTarget>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.warriorNavy,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: Colors.grey.shade50,
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(
                        color: AppColors.warriorNavy.withValues(alpha: 0.08),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    segments: const <ButtonSegment<ProfileTarget>>[
                      ButtonSegment<ProfileTarget>(
                        value: ProfileTarget.cpns,
                        label: Text(
                          'CPNS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ButtonSegment<ProfileTarget>(
                        value: ProfileTarget.bumn,
                        label: Text(
                          'BUMN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    selected: profileSettings.target == null
                        ? const <ProfileTarget>{}
                        : <ProfileTarget>{profileSettings.target!},
                    onSelectionChanged: (Set<ProfileTarget> selected) {
                      if (selected.isEmpty) {
                        return;
                      }
                      settingsController.setTarget(selected.first);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Target aktif: ${profileSettings.target?.label ?? '-'}',
                  key: const Key('active-target-label'),
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.warriorNavy.withValues(alpha: 0.06),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.warriorNavy.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                _SettingsSwitchTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.levelUpTeal,
                  title: 'Notifikasi Harian',
                  subtitle: 'Ingat belajar setiap hari',
                  value: profileSettings.notificationsEnabled,
                  onChanged: settingsController.toggleNotifications,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                _SettingsSwitchTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: AppColors.fireGold,
                  title: 'Suara Efek',
                  subtitle: 'Efek suara dalam game kuis',
                  value: profileSettings.soundEnabled,
                  onChanged: settingsController.toggleSound,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                _SettingsSwitchTile(
                  icon: Icons.vibration_rounded,
                  iconColor: AppColors.warriorNavy,
                  title: 'Haptic Feedback',
                  subtitle: 'Sentuhan getaran responsif',
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
  const _ProfileHeaderCard({required this.progress, required this.targetLabel});

  final PlayerProgress progress;
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    final String avatarInitial = progress.displayName.isEmpty
        ? '?'
        : progress.displayName.substring(0, 1).toUpperCase();

    final String progressText = progress.nextTier == null
        ? 'Tier Maksimal'
        : 'Sisa ${progress.pointsUntilNextTier} poin menuju ${progress.nextTier!.label}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.warriorNavy, Color(0xFF0C3D9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.fireGold.withValues(alpha: 0.85),
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.scholarCream.withAlpha(40),
                      child: Text(
                        avatarInitial,
                        style: const TextStyle(
                          color: AppColors.scholarCream,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Avatar customization coming soon'),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.fireGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: AppColors.warriorNavy,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      progress.displayName,
                      style: const TextStyle(
                        color: AppColors.scholarCream,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.levelUpTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            progress.tier.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (targetLabel != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.scholarCream.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              targetLabel!,
                              style: const TextStyle(
                                color: AppColors.scholarCream,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Progress Tier',
                style: TextStyle(
                  color: AppColors.scholarCream,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${progress.totalPoints} Poin',
                style: const TextStyle(
                  color: AppColors.fireGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.tierProgress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.fireGold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressText,
            style: TextStyle(
              color: AppColors.scholarCream.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: children,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warriorNavy.withValues(alpha: 0.06),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      activeThumbColor: AppColors.levelUpTeal,
      activeTrackColor: AppColors.levelUpTeal.withValues(alpha: 0.2),
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade200,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textStrong,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
