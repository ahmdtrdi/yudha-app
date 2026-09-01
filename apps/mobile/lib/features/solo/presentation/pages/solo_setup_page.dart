import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloSetupPage extends ConsumerWidget {
  const SoloSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SoloSetupState state = ref.watch(soloSetupControllerProvider);
    final controller = ref.read(soloSetupControllerProvider.notifier);

    void continueSetup() {
      final SoloSetupMode? mode = state.mode;
      if (mode == null) return;
      if (state.usesUnavailableRecommendation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rekomendasi personal belum tersedia. Pilih Seimbang atau Pilih topik.',
            ),
          ),
        );
        return;
      }
      if (mode == SoloSetupMode.custom && state.legacyTopic == null) {
        context.push(AppRoutes.soloTopics);
        return;
      }
      context.push(AppRoutes.soloLoadout);
    }

    final String actionLabel = switch (state.mode) {
      SoloSetupMode.custom when state.legacyTopic == null => 'PILIH TOPIK',
      SoloSetupMode.auto ||
      SoloSetupMode.recommended => 'REKOMENDASI BELUM TERSEDIA',
      _ => 'LANJUT PILIH KARAKTER',
    };

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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxHeight < 620;
                  final bool dense = constraints.maxHeight < 460;
                  final double heroHeight = compact
                      ? 160
                      : (constraints.maxHeight * 0.27).clamp(160, 205);
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compact ? 8 : 12,
                      16,
                      compact ? 92 : 104,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: constraints.maxWidth - 32,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _SectionTitle(
                              label: 'SESI UNTUKMU',
                              compact: compact,
                            ),
                            SizedBox(height: compact ? 5 : 8),
                            SizedBox(
                              height: heroHeight,
                              child: _RecommendedSessionCard(
                                selected: state.mode == SoloSetupMode.auto,
                                onTap: () =>
                                    controller.selectMode(SoloSetupMode.auto),
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 14),
                            _SectionTitle(
                              label: 'ATUR SENDIRI',
                              compact: compact,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih ritme dan materi sesuai kebutuhanmu.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: compact ? 9 : 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: compact ? 6 : 10),
                            _ControlLabel(
                              label: 'CARA LATIHAN',
                              compact: compact,
                            ),
                            SizedBox(height: compact ? 4 : 6),
                            _MechanicSelector(
                              selected: state.mode == SoloSetupMode.auto
                                  ? null
                                  : state.mechanicMode,
                              compact: dense,
                              onSelected: controller.selectMechanic,
                            ),
                            SizedBox(height: compact ? 8 : 12),
                            _ControlLabel(label: 'MATERI', compact: compact),
                            SizedBox(height: compact ? 4 : 6),
                            SizedBox(
                              height: dense ? 80 : (compact ? 100 : 104),
                              child: Row(
                                children: <Widget>[
                                  for (
                                    int index = 0;
                                    index < _customModeSpecs.length;
                                    index++
                                  ) ...[
                                    Expanded(
                                      child: _SoloModeCard(
                                        spec: _customModeSpecs[index],
                                        selected:
                                            state.mode ==
                                            _customModeSpecs[index].mode,
                                        onTap: () => controller.selectMode(
                                          _customModeSpecs[index].mode,
                                        ),
                                      ),
                                    ),
                                    if (index < _customModeSpecs.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 12),
                            _SoloSetupButton(
                              label: actionLabel,
                              enabled: state.mode != null,
                              unavailable: state.usesUnavailableRecommendation,
                              compact: dense,
                              onPressed: continueSetup,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
    unavailable: true,
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
  const _RecommendedSessionCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CosmeticItem arena = GameEconomyCatalog.findArena(
      GameEconomyCatalog.defaultArenaId,
    )!;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sesi untukmu: Focus, Rekomendasi, segera hadir',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1259C6),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 9,
            child: Material(
              color: const Color(0xFF173A67),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('solo-mode-auto'),
                onTap: onTap,
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
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF69A6FF)
                              : Colors.white70,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 10,
                      right: 10,
                      child: Tooltip(
                        message: 'Segera hadir',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xE6FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFF2878F0),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 58,
                      bottom: 13,
                      left: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Wrap(
                            spacing: 6,
                            children: <Widget>[
                              _RecommendationPill(
                                icon: Icons.self_improvement_rounded,
                                label: 'Focus',
                                color: Color(0xFF2878F0),
                              ),
                              _RecommendationPill(
                                icon: Icons.insights_rounded,
                                label: 'Rekomendasi',
                                color: Color(0xFFF08A36),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Latihan sesuai progresmu',
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
                        ],
                      ),
                    ),
                    Positioned(
                      right: 13,
                      bottom: 14,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9EC5FF),
                            width: 1.5,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x66062B67),
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          key: const ValueKey<String>(
                            'solo-recommended-action-icon',
                          ),
                          selected
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: const Color(0xFF2878F0),
                          size: 20,
                        ),
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
      height: compact ? 52 : 68,
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
    required this.onTap,
  });

  final SoloMechanicMode mode;
  final bool selected;
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

    return Semantics(
      key: ValueKey<String>('solo-mechanic-card-${mode.wireValue}'),
      button: true,
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
                key: ValueKey<String>('solo-mechanic-${mode.wireValue}'),
                onTap: onTap,
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
                          Icon(icon, color: const Color(0xFF2878F0), size: 19),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: GoogleFonts.fredoka(
                                  color: AppColors.warriorNavy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
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
                onTap: onTap,
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
  });

  final String label;
  final bool enabled;
  final bool unavailable;
  final bool compact;
  final VoidCallback onPressed;

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
              key: const ValueKey<String>('solo-setup-button-surface'),
              color: enabled && !unavailable
                  ? const Color(0xFFFFD49B)
                  : const Color(0xFFE6E8EC),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('solo-setup-continue'),
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
