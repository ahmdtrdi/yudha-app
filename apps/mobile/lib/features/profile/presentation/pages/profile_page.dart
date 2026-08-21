import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/progress_tier.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_providers.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_state.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait(<Future<void>>[
      ref.read(userProfileProvider.notifier).load(),
      ref.read(performanceAnalyticsProvider.notifier).load(),
      ref.read(playerProgressProvider.notifier).hydrateFromRepository(),
    ]);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _EditProfileSheet(
        profile: profile,
        onSaved: (UserProfile updated) {
          ref
              .read(playerProgressProvider.notifier)
              .setDisplayName(updated.displayName);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerProgress progress = ref.watch(playerProgressProvider);
    final profileSettings = ref.watch(profileSettingsProvider);
    final settingsController = ref.read(profileSettingsProvider.notifier);
    final UserProfileState profileState = ref.watch(userProfileProvider);
    final PerformanceAnalyticsState performanceState = ref.watch(
      performanceAnalyticsProvider,
    );
    final UserProfile? profile = profileState.profile;
    final String displayName = profile?.displayName ?? progress.displayName;
    final ProfileTarget? target = profile?.target ?? profileSettings.target;
    final int rankPoints = profile?.rankPoints ?? progress.totalPoints;
    final ProgressTier derivedTier = ProgressTier.fromPoints(rankPoints);
    final String tierLabel = profile?.tier == null
        ? derivedTier.label
        : _humanizeIdentifier(profile!.tier!);
    final ProfileRankedStats rankedStats =
        profile?.rankedStats ??
        ProfileRankedStats(
          wins: progress.wins,
          losses: progress.losses,
          draws: progress.draws,
          winRate: progress.winRate,
        );
    final int currentStreak = profile?.streak?.current ?? progress.streak;
    final int bestStreak = profile?.streak?.best ?? progress.bestStreak;

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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
        actions: <Widget>[
          IconButton(
            key: const Key('edit-profile-button'),
            tooltip: 'Edit profil',
            onPressed: profile == null
                ? null
                : () => _openEditor(context, ref, profile),
            icon: const Icon(Icons.edit_outlined, color: AppColors.warriorNavy),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            _ProfileHeaderCard(
              displayName: displayName,
              username: profile?.username,
              targetLabel: target?.label,
              rankPoints: rankPoints,
              tier: derivedTier,
              tierLabel: tierLabel,
              yCoins: profile?.yCoins,
              onEdit: profile == null
                  ? null
                  : () => _openEditor(context, ref, profile),
            ),
            if (profileState.status == UserProfileStatus.loading) ...<Widget>[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.levelUpTeal,
              ),
            ],
            if (profileState.errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              _ProfileErrorBanner(
                message: profileState.errorMessage!,
                onRetry: () => ref.read(userProfileProvider.notifier).load(),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionTitle(
              icon: Icons.bar_chart_rounded,
              title: 'Performa PvP',
            ),
            const SizedBox(height: 10),
            _RankedOverviewCard(stats: rankedStats),
            const SizedBox(height: 10),
            _StreakOverview(
              currentStreak: currentStreak,
              bestStreak: bestStreak,
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              icon: Icons.insights_rounded,
              title: 'Analisis Latihan',
            ),
            const SizedBox(height: 10),
            _PerformanceSection(
              state: performanceState,
              onRetry: () =>
                  ref.read(performanceAnalyticsProvider.notifier).load(),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              icon: Icons.tune_rounded,
              title: 'Pengaturan Profil',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.warriorNavy.withValues(alpha: 0.06),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFD1D5DC),
                    blurRadius: 0,
                    offset: const Offset(0, 7),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: Colors.black12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final bool shouldLogout =
                              await _showLogoutDialog(context) ?? false;
                          if (!shouldLogout) {
                            return;
                          }
                          await ref.read(authProvider.notifier).logout();
                          if (!context.mounted) {
                            return;
                          }
                          context.go(AppRoutes.login);
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFD92D20)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        label: const Text(
                          'Keluar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorBanner extends StatelessWidget {
  const _ProfileErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3B5AD)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB42318),
            size: 18,
          ),
          const SizedBox(width: 9),
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
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile, required this.onSaved});

  final UserProfile profile;
  final ValueChanged<UserProfile> onSaved;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late ProfileTarget _target;
  String? _validationError;
  bool _allowPop = false;

  bool get _isDirty =>
      _usernameController.text.trim() != widget.profile.username ||
      _fullNameController.text.trim() != widget.profile.fullName ||
      _target != widget.profile.target;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username)
      ..addListener(_onFieldChanged);
    _fullNameController = TextEditingController(text: widget.profile.fullName)
      ..addListener(_onFieldChanged);
    _target = widget.profile.target;
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() => _validationError = null);
    }
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _fullNameController
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _requestClose() async {
    final UserProfileState state = ref.read(userProfileProvider);
    if (state.status == UserProfileStatus.saving) {
      return;
    }
    if (!_isDirty) {
      setState(() => _allowPop = true);
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final bool discard =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Buang perubahan?'),
            content: const Text(
              'Perubahan profil yang belum disimpan akan hilang.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Lanjut edit'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Buang'),
              ),
            ],
          ),
        ) ??
        false;
    if (!discard || !mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final String username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() {
        _validationError = 'Username minimal terdiri dari 3 karakter.';
      });
      return;
    }

    final UserProfile? updated = await ref
        .read(userProfileProvider.notifier)
        .save(
          UserProfileUpdate(
            username: username,
            fullName: _fullNameController.text,
            target: _target,
          ),
        );
    if (updated == null || !mounted) {
      return;
    }
    widget.onSaved(updated);
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final UserProfileState state = ref.watch(userProfileProvider);
    final bool isSaving = state.status == UserProfileStatus.saving;
    final String? errorMessage = _validationError ?? state.errorMessage;

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_requestClose());
        }
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: FractionallySizedBox(
              heightFactor: 0.82,
              widthFactor: 1,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 8, 8),
                      child: Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Edit Profil',
                              style: TextStyle(
                                color: AppColors.warriorNavy,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tutup',
                            onPressed: isSaving ? null : _requestClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.warriorNavy.withAlpha(20),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TextField(
                              key: const Key('profile-full-name-field'),
                              controller: _fullNameController,
                              enabled: !isSaving,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nama lengkap',
                                hintText: 'Nama yang tampil di profil',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('profile-username-field'),
                              controller: _usernameController,
                              enabled: !isSaving,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                hintText: 'Minimal 3 karakter',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Target belajar',
                              style: TextStyle(
                                color: AppColors.textStrong,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ProfileTarget>(
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
                                selected: <ProfileTarget>{_target},
                                onSelectionChanged: isSaving
                                    ? null
                                    : (Set<ProfileTarget> selected) {
                                        setState(() {
                                          _target = selected.first;
                                          _validationError = null;
                                        });
                                      },
                              ),
                            ),
                            if (errorMessage != null) ...<Widget>[
                              const SizedBox(height: 16),
                              Text(
                                errorMessage,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('save-profile-button'),
                            onPressed: !_isDirty || isSaving ? null : _save,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.warriorNavy,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
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

Future<bool?> _showLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.warriorNavy.withValues(alpha: 0.08),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.warriorNavy.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD92D20).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB42318),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Keluar dari akun?',
                      style: TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Kamu akan kembali ke halaman login dan perlu masuk lagi untuk melanjutkan.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warriorNavy,
                        side: BorderSide(
                          color: AppColors.warriorNavy.withValues(alpha: 0.18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD92D20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ya, keluar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.username,
    required this.targetLabel,
    required this.rankPoints,
    required this.tier,
    required this.tierLabel,
    required this.yCoins,
    required this.onEdit,
  });

  final String displayName;
  final String? username;
  final String? targetLabel;
  final int rankPoints;
  final ProgressTier tier;
  final String tierLabel;
  final int? yCoins;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String avatarInitial = displayName.isEmpty
        ? '?'
        : displayName.substring(0, 1).toUpperCase();

    final ProgressTier? nextTier = tier.nextTier;
    final int tierSpan = nextTier == null
        ? 0
        : nextTier.minPoints - tier.minPoints;
    final double tierProgress = nextTier == null
        ? 1
        : ((rankPoints - tier.minPoints) / tierSpan).clamp(0, 1).toDouble();
    final int pointsUntilNextTier = nextTier == null
        ? 0
        : (nextTier.minPoints - rankPoints).clamp(0, nextTier.minPoints);
    final String progressText = nextTier == null
        ? 'Tier maksimal sudah tercapai'
        : '$pointsUntilNextTier poin lagi menuju ${nextTier.label}';
    final String normalizedUsername = username?.trim() ?? '';

    return Stack(
      children: <Widget>[
        Positioned.fill(
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF072C78),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0D49B5),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF75E0E8),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 31,
                          backgroundColor: const Color(0xFF087C9E),
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
                        child: Material(
                          color: AppColors.fireGold,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: onEdit,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: AppColors.warriorNavy,
                              ),
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
                          displayName,
                          style: const TextStyle(
                            color: AppColors.scholarCream,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        if (normalizedUsername.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            '@$normalizedUsername',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
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
                                tierLabel,
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
                  if (yCoins != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 19,
                            height: 19,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.fireGold,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'Y',
                              style: TextStyle(
                                color: AppColors.warriorNavy,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$yCoins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    '$rankPoints Poin',
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
                  value: tierProgress,
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
        ),
      ],
    );
  }
}

class _RankedOverviewCard extends StatelessWidget {
  const _RankedOverviewCard({required this.stats});

  final ProfileRankedStats stats;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          top: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFD3D8E2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 122,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CustomPaint(
                      size: const Size.square(122),
                      painter: _RankedDonutPainter(stats),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatWinRate(stats.winRate),
                          style: const TextStyle(
                            color: AppColors.warriorNavy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'WIN RATE',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Ringkasan Ranked',
                      style: TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.totalMatches} pertandingan',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RankLegend(
                      color: const Color(0xFF16A7B7),
                      label: 'Menang',
                      value: stats.wins,
                    ),
                    const SizedBox(height: 8),
                    _RankLegend(
                      color: const Color(0xFFFFA15A),
                      label: 'Kalah',
                      value: stats.losses,
                    ),
                    const SizedBox(height: 8),
                    _RankLegend(
                      color: const Color(0xFFAAB3C2),
                      label: 'Seri',
                      value: stats.draws,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankLegend extends StatelessWidget {
  const _RankLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RankedDonutPainter extends CustomPainter {
  const _RankedDonutPainter(this.stats);

  final ProfileRankedStats stats;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final int total = stats.totalMatches;
    if (total == 0) {
      canvas.drawArc(
        rect.deflate(10),
        0,
        math.pi * 2,
        false,
        paint..color = const Color(0xFFE3E6EC),
      );
      return;
    }
    double start = -math.pi / 2;
    final List<(int, Color)> segments = <(int, Color)>[
      (stats.wins, const Color(0xFF16A7B7)),
      (stats.losses, const Color(0xFFFFA15A)),
      (stats.draws, const Color(0xFFAAB3C2)),
    ];
    for (final (int amount, Color color) in segments) {
      if (amount == 0) continue;
      final double sweep = math.pi * 2 * amount / total;
      canvas.drawArc(
        rect.deflate(10),
        start + 0.035,
        math.max(0, sweep - 0.07),
        false,
        paint..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RankedDonutPainter oldDelegate) =>
      oldDelegate.stats != stats;
}

class _StreakOverview extends StatelessWidget {
  const _StreakOverview({
    required this.currentStreak,
    required this.bestStreak,
  });

  final int currentStreak;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _PassiveStatTile(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak saat ini',
            value: '$currentStreak hari',
            fill: const Color(0xFFFFE8D6),
            accent: const Color(0xFFD76B21),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PassiveStatTile(
            icon: Icons.workspace_premium_rounded,
            label: 'Streak terbaik',
            value: '$bestStreak hari',
            fill: const Color(0xFFEDE7F7),
            accent: const Color(0xFF7450A8),
          ),
        ),
      ],
    );
  }
}

class _PassiveStatTile extends StatelessWidget {
  const _PassiveStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.fill,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color fill;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
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

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({required this.state, required this.onRetry});

  final PerformanceAnalyticsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PerformanceAnalytics? analytics = state.analytics;
    if (analytics == null) {
      return switch (state.status) {
        PerformanceAnalyticsStatus.error => _PerformanceMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Performa belum dapat dimuat',
          message:
              state.errorMessage ??
              'Tarik layar atau coba lagi untuk memuat ringkasanmu.',
          actionLabel: 'Coba lagi',
          onAction: onRetry,
        ),
        _ => const _PerformanceMessage(
          icon: Icons.insights_rounded,
          title: 'Menyiapkan ringkasan performa',
          message: 'Sebentar, kami sedang merangkum hasil latihanmu.',
          isLoading: true,
        ),
      };
    }

    if (!analytics.hasAnyActivity) {
      return _PerformanceMessage(
        icon: Icons.track_changes_rounded,
        title: 'Belum ada hasil untuk dirangkum',
        message:
            'Selesaikan latihan atau pertandingan pertamamu untuk melihat perkembangan di sini.',
        actionLabel: state.status == PerformanceAnalyticsStatus.error
            ? 'Coba lagi'
            : null,
        onAction: state.status == PerformanceAnalyticsStatus.error
            ? onRetry
            : null,
      );
    }

    final PracticePerformance practice = analytics.practice;
    final bool hasPractice = practice.totalAnswered > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.status == PerformanceAnalyticsStatus.loading) ...<Widget>[
          const LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.levelUpTeal,
          ),
          const SizedBox(height: 8),
        ],
        if (state.status == PerformanceAnalyticsStatus.error &&
            state.errorMessage != null) ...<Widget>[
          _ProfileErrorBanner(message: state.errorMessage!, onRetry: onRetry),
          const SizedBox(height: 10),
        ],
        _PracticeOverviewCard(practice: practice, hasPractice: hasPractice),
        const SizedBox(height: 10),
        _MetricGrid(
          children: <Widget>[
            _MetricCard(
              label: 'Waktu respons',
              value: hasPractice
                  ? _formatResponseTime(practice.averageResponseTimeMs)
                  : '-',
              detail: 'Rata-rata per jawaban',
              icon: Icons.timer_outlined,
              iconColor: AppColors.warriorNavy,
            ),
            _MetricCard(
              label: 'Soal dijawab',
              value: '${practice.totalAnswered}',
              detail: 'Dari seluruh latihan',
              icon: Icons.fact_check_outlined,
              iconColor: const Color(0xFF7A4DA3),
            ),
          ],
        ),
        if (practice.categoryBreakdown.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _CategoryPerformancePanel(items: practice.categoryBreakdown),
        ],
        if (hasPractice) ...<Widget>[
          const SizedBox(height: 12),
          _WeakTopicsPanel(items: practice.weakSubcategories),
        ],
      ],
    );
  }
}

class _PerformanceMessage extends StatelessWidget {
  const _PerformanceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.warriorNavy.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.levelUpTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.levelUpTeal,
                    ),
                  )
                : Icon(icon, size: 20, color: AppColors.levelUpTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPerformancePanel extends StatelessWidget {
  const _CategoryPerformancePanel({required this.items});

  final List<CategoryPerformance> items;

  @override
  Widget build(BuildContext context) {
    return _PerformancePanel(
      title: 'Akurasi per kategori',
      icon: Icons.stacked_bar_chart_rounded,
      children: <Widget>[
        for (int index = 0; index < items.length; index++) ...<Widget>[
          _AccuracyRow(
            label: _humanizeIdentifier(items[index].category),
            accuracy: items[index].accuracy,
            totalAnswered: items[index].totalAnswered,
          ),
          if (index < items.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _WeakTopicsPanel extends StatelessWidget {
  const _WeakTopicsPanel({required this.items});

  final List<SubcategoryPerformance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PerformancePanel(
        title: 'Fokus latihan',
        icon: Icons.task_alt_rounded,
        children: <Widget>[
          Text(
            'Belum ada topik yang perlu perhatian khusus. Pertahankan ritme latihanmu.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return _PerformancePanel(
      title: 'Fokus latihan berikutnya',
      icon: Icons.center_focus_strong_rounded,
      children: <Widget>[
        for (int index = 0; index < items.length; index++) ...<Widget>[
          _WeakTopicRow(item: items[index]),
          if (index < items.length - 1)
            const Divider(height: 20, color: Colors.black12),
        ],
      ],
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.warriorNavy.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.warriorNavy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow({
    required this.label,
    required this.accuracy,
    required this.totalAnswered,
  });

  final String label;
  final double accuracy;
  final int totalAnswered;

  @override
  Widget build(BuildContext context) {
    final double progress = (accuracy / 100).clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _formatPercent(accuracy),
              style: const TextStyle(
                color: AppColors.warriorNavy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.scholarCream,
            color: accuracy < 60 ? AppColors.fireGold : AppColors.levelUpTeal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalAnswered soal dijawab',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _WeakTopicRow extends StatelessWidget {
  const _WeakTopicRow({required this.item});

  final SubcategoryPerformance item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.fireGold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_upward_rounded,
            size: 17,
            color: Color(0xFFB65D00),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _humanizeIdentifier(item.subcategory),
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.totalAnswered} soal menjadi dasar penilaian',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatPercent(item.accuracy),
          style: const TextStyle(
            color: Color(0xFFB65D00),
            fontSize: 12,
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
      childAspectRatio: 1.75,
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
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(18),
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
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeOverviewCard extends StatelessWidget {
  const _PracticeOverviewCard({
    required this.practice,
    required this.hasPractice,
  });

  final PracticePerformance practice;
  final bool hasPractice;

  @override
  Widget build(BuildContext context) {
    final double progress = (practice.overallAccuracy / 100)
        .clamp(0, 1)
        .toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF83E7FF).withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFBFEFF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: Color(0xFF087C9E),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Akurasi latihan',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      hasPractice
                          ? _formatPercent(practice.overallAccuracy)
                          : '-',
                      style: const TextStyle(
                        color: AppColors.warriorNavy,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        hasPractice
                            ? '${practice.totalAnswered} soal dinilai'
                            : 'Belum ada latihan',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: hasPractice ? progress : 0,
                    minHeight: 7,
                    backgroundColor: Colors.white,
                    color: const Color(0xFF16A7B7),
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

String _formatPercent(double value) => '${value.round().clamp(0, 100)}%';

String _formatWinRate(double value) =>
    '${(value * 100).round().clamp(0, 100)}%';

String _formatResponseTime(int milliseconds) {
  if (milliseconds <= 0) {
    return '-';
  }
  if (milliseconds < 1000) {
    return '$milliseconds md';
  }
  final String seconds = (milliseconds / 1000)
      .toStringAsFixed(milliseconds % 1000 == 0 ? 0 : 1)
      .replaceAll('.', ',');
  return '$seconds dtk';
}

String _humanizeIdentifier(String value) {
  final List<String> words = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  return words
      .map((String word) {
        final String upper = word.toUpperCase();
        if (<String>{'TWK', 'TIU', 'TKP'}.contains(upper)) {
          return upper;
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
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
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
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
      ),
    );
  }
}
