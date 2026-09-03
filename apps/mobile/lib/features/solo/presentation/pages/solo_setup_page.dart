import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloSetupPage extends ConsumerStatefulWidget {
  const SoloSetupPage({super.key});

  @override
  ConsumerState<SoloSetupPage> createState() => _SoloSetupPageState();
}

class _SoloSetupPageState extends ConsumerState<SoloSetupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(learningControllerProvider.notifier).load();
      final nextAction = ref.read(learningControllerProvider).dashboard?.nextAction;
      if (nextAction != null) {
        ref.read(soloSetupControllerProvider.notifier).applyRecommendedPreset(nextAction);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SoloSetupState state = ref.watch(soloSetupControllerProvider);
    final controller = ref.read(soloSetupControllerProvider.notifier);
    final activeSession = ref.watch(activeSoloSessionProvider).asData?.value;
    final learningState = ref.watch(learningControllerProvider);
    final nextAction = learningState.dashboard?.nextAction;

    ref.listen<LearningState>(learningControllerProvider, (previous, next) {
      final rec = next.dashboard?.nextAction;
      if (rec != null && ref.read(soloSetupControllerProvider).recommendationId == null) {
        ref.read(soloSetupControllerProvider.notifier).applyRecommendedPreset(rec);
      }
    });

    if (nextAction != null && state.recommendationId == null && (state.mode == null || state.mode == SoloSetupMode.auto || state.mode == SoloSetupMode.balanced)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.applyRecommendedPreset(nextAction);
      });
    }

    Future<void> continueManualSetup(SoloSetupState draft) async {
      final SoloSetupMode? mode = draft.mode;
      if (mode == null) return;
      if (mode == SoloSetupMode.custom && draft.legacyTopic == null) {
        Navigator.of(context, rootNavigator: true).pop();
        await context.push(AppRoutes.soloTopics);
        return;
      }
      if (!draft.canOpenLoadout) return;
      Navigator.of(context, rootNavigator: true).pop();
      await context.push(AppRoutes.soloLoadout);
    }

    Future<void> openManualSetup() async {
      final bool hasDraft =
          state.mode != null && state.mode != SoloSetupMode.auto;
      if (!hasDraft) {
        if (nextAction != null) {
          controller.applyRecommendedPreset(nextAction);
        } else {
          controller.beginManualSetup();
        }
      }
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) =>
            _ManualSetupSheet(onContinue: continueManualSetup),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        key: const ValueKey<String>('solo-top-bar'),
        backgroundColor: const Color(0xFF0D49B5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        centerTitle: true,
        actions: <Widget>[
          if (activeSession != null)
            IconButton(
              key: const ValueKey<String>('solo-resume-session'),
              tooltip: 'Lanjutkan sesi',
              icon: const Icon(Icons.play_circle_fill_rounded),
              onPressed: () async {
                final sessionController = ref.read(
                  soloSessionControllerProvider.notifier,
                );
                final bool resumed = await sessionController.resume(
                  activeSession.id,
                );
                if (!context.mounted) return;
                if (resumed) {
                  context.go(AppRoutes.soloSession);
                  return;
                }
                final String message =
                    ref.read(soloSessionControllerProvider).error ??
                    'Sesi belum bisa dilanjutkan. Coba lagi.';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              },
            ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.auto_awesome_rounded, size: 21),
            const SizedBox(width: 8),
            Text(
              'LATIHAN SOLO',
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 16,
              child: ColoredBox(
                color: AppColors.scholarCream,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const DecoratedBox(
                      key: ValueKey<String>('solo-top-bar-depth'),
                      decoration: BoxDecoration(
                        color: Color(0xFF06378F),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: ClipRRect(
                        key: ValueKey<String>('solo-top-bar-surface'),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                        child: ColoredBox(color: Color(0xFF0D49B5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey<String>('solo-recommended-scroll-view'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _SectionTitle(label: 'SESI UNTUKMU', compact: false),
                    const SizedBox(height: 4),
                    const Text(
                      'Konfigurasi siap main yang aman untuk memulai.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 290,
                      child: _RecommendedSessionCard(
                        recommendation: nextAction,
                        isLoading: learningState.status == LearningViewStatus.loading,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SoloSetupButton(
                      label: nextAction != null ? 'MAIN SESI REKOMENDASI' : 'LANJUT PILIH KARAKTER',
                      enabled: true,
                      unavailable: false,
                      compact: false,
                      buttonKey: 'solo-recommended-continue',
                      surfaceKey: 'solo-recommended-button-surface',
                      onPressed: () {
                        controller.applyRecommendedPreset(nextAction);
                        context.push(AppRoutes.soloLoadout);
                      },
                    ),
                    const SizedBox(height: 10),
                    _ClaySecondaryButton(
                      label: 'ATUR SENDIRI',
                      onPressed: openManualSetup,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSetupSheet extends ConsumerWidget {
  const _ManualSetupSheet({required this.onContinue});

  final Future<void> Function(SoloSetupState) onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SoloSetupState state = ref.watch(soloSetupControllerProvider);
    final controller = ref.read(soloSetupControllerProvider.notifier);
    final learningState = ref.watch(learningControllerProvider);
    final nextAction = learningState.dashboard?.nextAction;
    final String actionLabel = switch (state.mode) {
      SoloSetupMode.custom when state.legacyTopic == null => 'PILIH TOPIK',
      SoloSetupMode.recommended when state.recommendationId == null && nextAction == null =>
        'REKOMENDASI BELUM TERSEDIA',
      SoloSetupMode.balanced when !state.canOpenLoadout => 'LENGKAPI SETUP',
      _ => 'LANJUT PILIH KARAKTER',
    };
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return SafeArea(
      top: false,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (BuildContext context, double progress, Widget? child) {
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - progress)),
              child: child,
            ),
          );
        },
        child: Container(
          key: const ValueKey<String>('solo-manual-sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: AppColors.scholarCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.warriorNavy.withAlpha(32),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionTitle(label: 'ATUR SENDIRI', compact: false),
                const SizedBox(height: 3),
                const Text(
                  'Pilih ritme dan materi sesuai kebutuhanmu.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                const _ControlLabel(label: 'CARA LATIHAN', compact: false),
                const SizedBox(height: 7),
                _MechanicSelector(
                  selected: state.mechanicMode,
                  compact: false,
                  onSelected: controller.selectMechanic,
                ),
                const SizedBox(height: 14),
                const _ControlLabel(label: 'JUMLAH SOAL', compact: false),
                const SizedBox(height: 7),
                _QuestionCountSelector(
                  selected: state.questionCount,
                  onSelected: controller.selectQuestionCount,
                ),
                const SizedBox(height: 14),
                const _ControlLabel(label: 'MATERI', compact: false),
                const SizedBox(height: 7),
                SizedBox(
                  height: 112,
                  child: Row(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < _customModeSpecs.length;
                        index++
                      ) ...<Widget>[
                        Expanded(
                          child: _SoloModeCard(
                            spec: _customModeSpecs[index].mode == SoloSetupMode.recommended && state.legacyTopic != null
                                ? _customModeSpecs[index].copyWithDescription(state.legacyTopic!.name)
                                : (_customModeSpecs[index].mode == SoloSetupMode.recommended && nextAction != null
                                    ? _customModeSpecs[index].copyWithDescription(
                                        nextAction.subcategory ?? nextAction.category ?? nextAction.skillLabel,
                                      )
                                    : _customModeSpecs[index]),
                            selected:
                                state.mode == _customModeSpecs[index].mode,
                            onTap: () {
                              final specMode = _customModeSpecs[index].mode;
                              if (specMode == SoloSetupMode.recommended) {
                                if (nextAction != null) {
                                  controller.selectRecommendation(nextAction);
                                } else {
                                  controller.selectMode(SoloSetupMode.recommended);
                                }
                              } else {
                                controller.selectMode(specMode);
                              }
                            },
                          ),
                        ),
                        if (index < _customModeSpecs.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SoloSetupButton(
                  label: actionLabel,
                  enabled:
                      state.canOpenLoadout ||
                      state.mode == SoloSetupMode.custom,
                  unavailable: state.usesUnavailableRecommendation,
                  compact: false,
                  onPressed: () => onContinue(state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoloModeSpec {
  const _SoloModeSpec({
    required this.mode,
    required this.title,
    required this.description,
    required this.arenaId,
    required this.accent,
    this.unavailable = false,
  });

  final SoloSetupMode mode;
  final String title;
  final String description;
  final String arenaId;
  final Color accent;
  final bool unavailable;

  CosmeticItem get arena => GameEconomyCatalog.findArena(arenaId)!;

  _SoloModeSpec copyWithDescription(String newDescription) => _SoloModeSpec(
    mode: mode,
    title: title,
    description: newDescription,
    arenaId: arenaId,
    accent: accent,
    unavailable: unavailable,
  );
}

const List<_SoloModeSpec> _customModeSpecs = <_SoloModeSpec>[
  _SoloModeSpec(
    mode: SoloSetupMode.balanced,
    title: 'Seimbang',
    description: 'Semua materi',
    arenaId: 'arena-rimba-yudha',
    accent: Color(0xFF20A778),
  ),
  _SoloModeSpec(
    mode: SoloSetupMode.recommended,
    title: 'Rekomendasi',
    description: 'Topik terlemah',
    arenaId: 'arena-lembah-bara',
    accent: Color(0xFFF08A36),
    unavailable: false,
  ),
  _SoloModeSpec(
    mode: SoloSetupMode.custom,
    title: 'Pilih topik',
    description: 'Atur materi',
    arenaId: 'arena-gurun-cendekia',
    accent: Color(0xFFB24EA6),
  ),
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.fredoka(
        color: AppColors.warriorNavy,
        fontSize: compact ? 15 : 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: compact ? 8 : 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RecommendedSessionCard extends StatelessWidget {
  const _RecommendedSessionCard({
    this.recommendation,
    this.isLoading = false,
  });

  final LearningRecommendation? recommendation;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final CosmeticItem arena = GameEconomyCatalog.findArena(
      'arena-rimba-yudha',
    )!;

    final String mechanicLabel;
    final IconData mechanicIcon;
    final Color mechanicColor;
    if (recommendation?.mechanicMode == 'focus') {
      mechanicLabel = 'Fokus';
      mechanicIcon = Icons.self_improvement_rounded;
      mechanicColor = const Color(0xFF2E7D32);
    } else if (recommendation?.mechanicMode == 'speed') {
      mechanicLabel = 'Speed';
      mechanicIcon = Icons.bolt_rounded;
      mechanicColor = const Color(0xFFD97706);
    } else {
      mechanicLabel = 'Standard';
      mechanicIcon = Icons.timer_outlined;
      mechanicColor = const Color(0xFF2878F0);
    }

    final String topicLabel = recommendation != null && recommendation!.skillLabel.isNotEmpty
        ? recommendation!.skillLabel
        : 'Seimbang';

    final String title = recommendation != null && recommendation!.skillLabel.isNotEmpty
        ? recommendation!.skillLabel
        : 'Rimba Yudha';

    final String subtitle = recommendation != null && recommendation!.reasonHeadline.isNotEmpty
        ? recommendation!.reasonHeadline
        : (recommendation != null && recommendation!.reasonDescription.isNotEmpty
            ? recommendation!.reasonDescription
            : 'Hancurkan satu tower dengan tiga kartu pilihan.');

    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              key: ValueKey<String>('solo-recommended-card-depth'),
              decoration: BoxDecoration(
                color: Color(0xFF0F2644),
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 9,
            child: DecoratedBox(
              key: const ValueKey<String>('solo-recommended-card'),
              decoration: BoxDecoration(
                color: const Color(0xFF173A67),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      key: const ValueKey<String>(
                        'solo-recommended-arena-preview',
                      ),
                      arena.assetPath!,
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x0014213A), Color(0xD914213A)],
                          stops: <double>[0.25, 1],
                        ),
                      ),
                    ),
                    if (isLoading && recommendation == null)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox.square(
                              dimension: 26,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Menyiapkan sesi rekomendasi...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...<Widget>[
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xE6FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Text(
                              'SIAP DIMAINKAN',
                              style: TextStyle(
                                color: Color(0xFF1B5FC4),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    Positioned(
                      right: 13,
                      bottom: 16,
                      left: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _RecommendationPill(
                                icon: mechanicIcon,
                                label: mechanicLabel,
                                color: mechanicColor,
                              ),
                              _RecommendationPill(
                                icon: Icons.auto_awesome_rounded,
                                label: topicLabel,
                                color: const Color(0xFF20A778),
                              ),
                              const _RecommendationPill(
                                icon: Icons.style_rounded,
                                label: '20 soal',
                                color: Color(0xFFF08A36),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              shadows: const <Shadow>[
                                Shadow(color: Colors.black54, blurRadius: 5),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPill extends StatelessWidget {
  const _RecommendationPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.warriorNavy,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MechanicSelector extends StatelessWidget {
  const _MechanicSelector({
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final SoloMechanicMode? selected;
  final bool compact;
  final ValueChanged<SoloMechanicMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('solo-mechanic-selector'),
      height: compact ? 64 : 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (
            int index = 0;
            index < SoloMechanicMode.values.length;
            index++
          ) ...[
            Expanded(
              child: _MechanicChoice(
                mode: SoloMechanicMode.values[index],
                selected: selected == SoloMechanicMode.values[index],
                enabled: true,
                onTap: () => onSelected(SoloMechanicMode.values[index]),
              ),
            ),
            if (index < SoloMechanicMode.values.length - 1)
              const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _MechanicChoice extends StatelessWidget {
  const _MechanicChoice({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SoloMechanicMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = switch (mode) {
      SoloMechanicMode.focus => 'Focus',
      SoloMechanicMode.standard => 'Standard',
      SoloMechanicMode.speed => 'Speed',
    };
    final IconData icon = switch (mode) {
      SoloMechanicMode.focus => Icons.self_improvement_rounded,
      SoloMechanicMode.standard => Icons.timer_outlined,
      SoloMechanicMode.speed => Icons.bolt_rounded,
    };
    final String description = switch (mode) {
      SoloMechanicMode.focus => 'Tanpa waktu',
      SoloMechanicMode.standard => 'Tempo normal',
      SoloMechanicMode.speed => 'Lebih cepat',
    };

    return _SoloSetupOptionCard(
      semanticsKey: ValueKey<String>('solo-mechanic-card-${mode.wireValue}'),
      tapKey: ValueKey<String>('solo-mechanic-${mode.wireValue}'),
      icon: icon,
      label: label,
      description: enabled ? description : 'Segera hadir',
      enabled: enabled,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _QuestionCountSelector extends StatelessWidget {
  const _QuestionCountSelector({
    required this.selected,
    required this.onSelected,
  });

  final SoloQuestionCount? selected;
  final ValueChanged<SoloQuestionCount> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('solo-question-count-selector'),
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final SoloQuestionCount count in SoloQuestionCount.values) ...[
            Expanded(
              child: _SoloSetupOptionCard(
                semanticsKey: ValueKey<String>(
                  'solo-question-count-card-${count.value}',
                ),
                tapKey: ValueKey<String>('solo-question-count-${count.value}'),
                icon: Icons.style_rounded,
                label: '${count.value} soal',
                description: switch (count) {
                  SoloQuestionCount.twenty => 'Sesi ringkas',
                  SoloQuestionCount.thirtyFive => 'Sesi sedang',
                  SoloQuestionCount.fifty => 'Sesi penuh',
                },
                enabled: true,
                selected: selected == count,
                onTap: () => onSelected(count),
              ),
            ),
            if (count != SoloQuestionCount.values.last)
              const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _SoloSetupOptionCard extends StatelessWidget {
  const _SoloSetupOptionCard({
    required this.semanticsKey,
    required this.tapKey,
    required this.icon,
    required this.label,
    required this.description,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final Key semanticsKey;
  final Key tapKey;
  final IconData icon;
  final String label;
  final String description;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      button: true,
      enabled: enabled,
      selected: selected,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF7BAEFF)
                    : const Color(0xFFD5D9E1),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 6,
            child: Material(
              color: selected
                  ? const Color(0xFFE5EEFF)
                  : const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: tapKey,
                onTap: enabled ? onTap : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? const Color(0xFF2878F0) : Colors.white,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            icon,
                            color: enabled
                                ? const Color(0xFF2878F0)
                                : AppColors.textMuted,
                            size: 19,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: GoogleFonts.fredoka(
                                  color: enabled
                                      ? AppColors.warriorNavy
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloModeCard extends StatelessWidget {
  const _SoloModeCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _SoloModeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !spec.unavailable,
      selected: selected,
      label: spec.title,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? spec.accent.withValues(alpha: 0.55)
                    : const Color(0xFFD4D7DD),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 5,
            child: Material(
              color: const Color(0xFF173A67),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey<String>('solo-mode-${spec.mode.name}'),
                onTap: spec.unavailable ? null : onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      key: ValueKey<String>(
                        'solo-mode-arena-preview-${spec.mode.name}',
                      ),
                      spec.arena.assetPath!,
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x0014213A), Color(0xE014213A)],
                          stops: <double>[0.35, 1],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? spec.accent : Colors.white70,
                          width: selected ? 3 : 1.2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 7,
                      left: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              shadows: const <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 5),
                              ],
                            ),
                          ),
                          Text(
                            spec.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: spec.accent,
                          size: 20,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.white, blurRadius: 4),
                          ],
                        ),
                      )
                    else if (spec.unavailable)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 17,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloSetupButton extends StatelessWidget {
  const _SoloSetupButton({
    required this.label,
    required this.enabled,
    required this.unavailable,
    required this.compact,
    required this.onPressed,
    this.buttonKey = 'solo-setup-continue',
    this.surfaceKey = 'solo-setup-button-surface',
  });

  final String label;
  final bool enabled;
  final bool unavailable;
  final bool compact;
  final VoidCallback onPressed;
  final String buttonKey;
  final String surfaceKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 52 : 58,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: enabled && !unavailable
                    ? const Color(0xFFF09A4B)
                    : const Color(0xFFC9CDD5),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 7,
            child: Material(
              key: ValueKey<String>(surfaceKey),
              color: enabled && !unavailable
                  ? const Color(0xFFFFD49B)
                  : const Color(0xFFE6E8EC),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey<String>(buttonKey),
                onTap: enabled ? onPressed : null,
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.fredoka(
                      color: enabled && !unavailable
                          ? const Color(0xFFB85C1E)
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaySecondaryButton extends StatelessWidget {
  const _ClaySecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        key: const ValueKey<String>('solo-open-manual'),
        onPressed: onPressed,
        icon: const Icon(Icons.tune_rounded),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1B5FC4),
          side: const BorderSide(color: Color(0xFF8DB8F3), width: 1.5),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.fredoka(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
