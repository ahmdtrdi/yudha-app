import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileOnboardingPage extends ConsumerStatefulWidget {
  const ProfileOnboardingPage({super.key});

  @override
  ConsumerState<ProfileOnboardingPage> createState() =>
      _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends ConsumerState<ProfileOnboardingPage> {
  final TextEditingController _nameController = TextEditingController();
  ProfileTarget? _selectedTarget;
  String? _nameError;
  String? _targetError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final ProfileTarget? target = _selectedTarget;

    setState(() {
      _nameError = name.isEmpty ? 'Nama wajib diisi.' : null;
      _targetError = target == null ? 'Pilih target belajar.' : null;
    });

    if (_nameError != null || _targetError != null || target == null) {
      return;
    }

    ref
        .read(profileSettingsProvider.notifier)
        .completeProfile(displayName: name, target: target);
    ref.read(playerProgressProvider.notifier).setDisplayName(name);

    context.go(AppRoutes.lobby);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
                    Text(
                      'Siapa nama kamu?',
                      style: GoogleFonts.orbitron(
                        color: AppColors.warriorNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lengkapi profil awal dulu sebelum masuk arena.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() {
                            _nameError = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Nama',
                        hintText: 'Contoh: Ahmad',
                        errorText: _nameError,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Target belajar',
                      style: GoogleFonts.dmSans(
                        color: AppColors.warriorNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ProfileTarget>(
                      emptySelectionAllowed: true,
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
                      selected: _selectedTarget == null
                          ? const <ProfileTarget>{}
                          : <ProfileTarget>{_selectedTarget!},
                      onSelectionChanged: (Set<ProfileTarget> selected) {
                        setState(() {
                          _selectedTarget =
                              selected.isEmpty ? null : selected.first;
                          _targetError = null;
                        });
                      },
                    ),
                    if (_targetError != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _targetError!,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFFB03030),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warriorNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Lanjut',
                          style: GoogleFonts.orbitron(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
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
