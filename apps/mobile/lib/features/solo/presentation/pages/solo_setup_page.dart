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
      _ => 'LANJUTKAN',
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
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'PILIH MODE',
                            style: GoogleFonts.fredoka(
                              color: AppColors.warriorNavy,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (
                            int index = 0;
                            index < _modeSpecs.length;
                            index++
                          ) ...[
                            _SoloModeCard(
                              spec: _modeSpecs[index],
                              selected: state.mode == _modeSpecs[index].mode,
                              selectedTopic:
                                  _modeSpecs[index].mode == SoloSetupMode.custom
                                  ? state.legacyTopic?.name
                                  : null,
                              onTap: () =>
                                  controller.selectMode(_modeSpecs[index].mode),
                            ),
                            if (index < _modeSpecs.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverToBoxAdapter(
                      child: _SoloSetupButton(
                        label: actionLabel,
                        enabled: state.mode != null,
                        onPressed: continueSetup,
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

class _SoloModeSpec {
  const _SoloModeSpec({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.arenaId,
    required this.accent,
    this.featured = false,
    this.availabilityLabel,
  });

  final SoloSetupMode mode;
  final String title;
  final String description;
  final IconData icon;
  final String arenaId;
  final Color accent;
  final bool featured;
  final String? availabilityLabel;

  CosmeticItem get arena => GameEconomyCatalog.findArena(arenaId)!;
}

const List<_SoloModeSpec> _modeSpecs = <_SoloModeSpec>[
  _SoloModeSpec(
    mode: SoloSetupMode.auto,
    title: 'Auto',
    description: 'Pilihan terbaik untukmu.',
    icon: Icons.auto_awesome_rounded,
    arenaId: GameEconomyCatalog.defaultArenaId,
    accent: Color(0xFF2878F0),
    featured: true,
    availabilityLabel: 'SEGERA HADIR',
  ),
  _SoloModeSpec(
    mode: SoloSetupMode.balanced,
    title: 'Seimbang',
    description: 'Campuran semua materi.',
    icon: Icons.balance_rounded,
    arenaId: 'arena-rimba-yudha',
    accent: Color(0xFF20A778),
  ),
  _SoloModeSpec(
    mode: SoloSetupMode.recommended,
    title: 'Rekomendasi',
    description: 'Perkuat materi terlemah.',
    icon: Icons.insights_rounded,
    arenaId: 'arena-lembah-bara',
    accent: Color(0xFFF08A36),
    availabilityLabel: 'SEGERA HADIR',
  ),
  _SoloModeSpec(
    mode: SoloSetupMode.custom,
    title: 'Pilih topik',
    description: 'Tentukan materi sendiri.',
    icon: Icons.tune_rounded,
    arenaId: 'arena-gurun-cendekia',
    accent: Color(0xFFB24EA6),
  ),
];

class _SoloModeCard extends StatelessWidget {
  const _SoloModeCard({
    required this.spec,
    required this.selected,
    required this.selectedTopic,
    required this.onTap,
  });

  final _SoloModeSpec spec;
  final bool selected;
  final String? selectedTopic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: spec.title,
      child: SizedBox(
        height: 120,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? spec.accent.withValues(alpha: 0.5)
                      : spec.featured
                      ? spec.accent.withValues(alpha: 0.28)
                      : const Color(0xFFD6D8DE),
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
            Positioned.fill(
              bottom: 7,
              child: Material(
                color: spec.featured ? const Color(0xFFF5F9FF) : Colors.white,
                borderRadius: BorderRadius.circular(23),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey<String>('solo-mode-${spec.mode.name}'),
                  onTap: onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: 152,
                        child: Image.asset(
                          spec.arena.assetPath!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          cacheWidth: 420,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Colors.white,
                              Colors.white,
                              Color(0xD9FFFFFF),
                              Color(0x22FFFFFF),
                            ],
                            stops: <double>[0, 0.48, 0.7, 1],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(
                            color: selected
                                ? spec.accent
                                : spec.featured
                                ? spec.accent.withValues(alpha: 0.72)
                                : const Color(0xFFE2E5EA),
                            width: selected || spec.featured ? 2 : 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 9, 118, 9),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                color: spec.accent.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(spec.icon, color: spec.accent),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          spec.title,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.fredoka(
                                            color: AppColors.warriorNavy,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (spec.featured) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          key: const ValueKey<String>(
                                            'solo-auto-featured',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: spec.accent,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'UTAMA',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    selectedTopic ?? spec.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 9.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (spec.availabilityLabel != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      spec.availabilityLabel!,
                                      style: TextStyle(
                                        color: spec.accent,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: selected ? spec.accent : Colors.white,
                          shadows: const <Shadow>[
                            Shadow(color: Color(0x66000000), blurRadius: 5),
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
      ),
    );
  }
}

class _SoloSetupButton extends StatelessWidget {
  const _SoloSetupButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF09A4B)
                    : const Color(0xFFD4D6DA),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 7,
            child: Material(
              color: enabled
                  ? const Color(0xFFFFD49B)
                  : const Color(0xFFECEDEF),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('solo-setup-continue'),
                onTap: enabled ? onPressed : null,
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.fredoka(
                      color: enabled
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
