import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait(<Future<void>>[
      ref.read(userProfileProvider.notifier).load(),
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
    final UserProfile? profile = profileState.profile;
    final String displayName = profile?.displayName ?? progress.displayName;
    final ProfileTarget? target = profile?.target ?? profileSettings.target;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: <Widget>[
            _ProfileHeaderCard(
              progress: progress,
              displayName: displayName,
              targetLabel: target?.label,
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
    required this.progress,
    required this.displayName,
    required this.targetLabel,
    required this.onEdit,
  });

  final PlayerProgress progress;
  final String displayName;
  final String? targetLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String avatarInitial = displayName.isEmpty
        ? '?'
        : displayName.substring(0, 1).toUpperCase();

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
