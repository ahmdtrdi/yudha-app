import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloLoadoutPage extends ConsumerWidget {
  const SoloLoadoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SoloSetupState setup = ref.watch(soloSetupControllerProvider);
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
    final controller = ref.read(soloSetupControllerProvider.notifier);
    final SoloSetupMode? mode = setup.mode;

    if (mode == null) {
      return _MissingSoloSetup(onBack: () => context.go(AppRoutes.solo));
    }

    final List<CosmeticItem> characters = economy.characters.isEmpty
        ? GameEconomyCatalog.characters
        : economy.characters;
    final String selectedId = setup.characterId ?? economy.equippedCharacterId;
    final CosmeticItem selectedCharacter = characters.firstWhere(
      (CosmeticItem item) => item.id == selectedId,
      orElse: () => characters.first,
    );
    final CosmeticItem arena = GameEconomyCatalog.findArena(
      _arenaIdForMode(mode),
    )!;

    Future<void> choosePace() async {
      final SoloMechanicMode? selected =
          await showModalBottomSheet<SoloMechanicMode>(
            context: context,
            backgroundColor: AppColors.scholarCream,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (BuildContext context) =>
                _PaceSheet(selected: setup.mechanicMode),
          );
      if (selected != null) controller.selectMechanic(selected);
    }

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) controller.reset();
      },
      child: Scaffold(
        backgroundColor: AppColors.scholarCream,
        appBar: AppBar(
          backgroundColor: AppColors.scholarCream,
          foregroundColor: AppColors.warriorNavy,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey<String>('solo-loadout-back'),
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          centerTitle: true,
          title: Text(
            'ATUR LATIHAN',
            style: GoogleFonts.fredoka(
              color: AppColors.warriorNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxHeight < 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _PaceSelector(mode: setup.mechanicMode, onTap: choosePace),
                    const SizedBox(height: 12),
                    _SoloCharacterStage(
                      arena: arena,
                      character: selectedCharacter,
                      mode: mode,
                      mechanicMode: setup.mechanicMode,
                      topicName: setup.legacyTopic?.name,
                      compact: compact,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Pilih karakter',
                            style: GoogleFonts.fredoka(
                              color: AppColors.warriorNavy,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: compact ? 112 : 120,
                      child: ListView.separated(
                        key: const ValueKey<String>('solo-character-list'),
                        scrollDirection: Axis.horizontal,
                        itemCount: characters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final CosmeticItem character = characters[index];
                          final bool owned = economy.owns(character.id);
                          return _CharacterChoiceCard(
                            character: character,
                            selected: character.id == selectedCharacter.id,
                            owned: owned,
                            onTap: () {
                              if (!owned) {
                                context.push(AppRoutes.store);
                                return;
                              }
                              controller.selectCharacter(character.id);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StartSoloButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Setup tersimpan. Sesi Solo belum diaktifkan pada commit ini.',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PaceSelector extends StatelessWidget {
  const _PaceSelector({required this.mode, required this.onTap});

  final SoloMechanicMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFD6D9DF),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 6,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('solo-pace-selector'),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EFFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: Color(0xFF2878F0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'TEMPO LATIHAN',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _mechanicLabel(mode),
                              style: GoogleFonts.fredoka(
                                color: AppColors.warriorNavy,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _mechanicDescription(mode),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.warriorNavy,
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

class _PaceSheet extends StatelessWidget {
  const _PaceSheet({required this.selected});

  final SoloMechanicMode selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Pilih tempo latihan',
              style: GoogleFonts.fredoka(
                color: AppColors.warriorNavy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final SoloMechanicMode mode in SoloMechanicMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  key: ValueKey<String>('solo-pace-${mode.wireValue}'),
                  onTap: () => Navigator.of(context).pop(mode),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                    side: BorderSide(
                      color: selected == mode
                          ? const Color(0xFF2878F0)
                          : const Color(0xFFE1E4E9),
                      width: selected == mode ? 2 : 1,
                    ),
                  ),
                  leading: Icon(
                    _mechanicIcon(mode),
                    color: const Color(0xFF2878F0),
                  ),
                  title: Text(
                    _mechanicLabel(mode),
                    style: GoogleFonts.fredoka(
                      color: AppColors.warriorNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(_mechanicDescription(mode)),
                  trailing: selected == mode
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2878F0),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SoloCharacterStage extends StatelessWidget {
  const _SoloCharacterStage({
    required this.arena,
    required this.character,
    required this.mode,
    required this.mechanicMode,
    required this.topicName,
    required this.compact,
  });

  final CosmeticItem arena;
  final CosmeticItem character;
  final SoloSetupMode mode;
  final SoloMechanicMode mechanicMode;
  final String? topicName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentForMode(mode);
    return AspectRatio(
      aspectRatio: compact ? 1.15 : 1.05,
      child: Container(
        key: const ValueKey<String>('solo-character-stage'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF173A67),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: accent, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              key: ValueKey<String>('solo-mode-arena-${mode.name}'),
              arena.assetPath!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: 900,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x22131D36), Color(0xB814213A)],
                  stops: <double>[0.35, 1],
                ),
              ),
            ),
            Positioned(
              top: 13,
              left: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _modeLabel(mode).toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 72,
              bottom: compact ? 31 : 34,
              left: 72,
              height: 17,
              child: DecoratedBox(
                key: const ValueKey<String>('solo-character-ground-shadow'),
                decoration: BoxDecoration(
                  color: const Color(0x66081424),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x55081424),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: compact ? 27 : 31,
              right: 56,
              bottom: compact ? 34 : 37,
              left: 56,
              child: Image.asset(
                key: const ValueKey<String>('solo-selected-character'),
                character.characterVisuals!.ready,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                cacheWidth: 480,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 12,
              left: 14,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          character.name,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                        Text(
                          topicName ?? '${_modeLabel(mode)} · ${arena.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE8EEFA),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD914213A),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      _mechanicLabel(mechanicMode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
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

class _CharacterChoiceCard extends StatelessWidget {
  const _CharacterChoiceCard({
    required this.character,
    required this.selected,
    required this.owned,
    required this.onTap,
  });

  final CosmeticItem character;
  final bool selected;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF85ACEF)
                    : const Color(0xFFD4D7DD),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 6,
            child: Material(
              color: selected
                  ? const Color(0xFFE5EEFF)
                  : const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey<String>('solo-character-${character.id}'),
                onTap: onTap,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 8,
                      right: 7,
                      bottom: 27,
                      left: 7,
                      child: _CharacterThumbnail(
                        character: character,
                        owned: owned,
                      ),
                    ),
                    Positioned(
                      right: 5,
                      bottom: 7,
                      left: 5,
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1B5FC4)
                              : AppColors.warriorNavy,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!owned)
                      const Positioned(
                        top: 7,
                        right: 7,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 15,
                          color: AppColors.textMuted,
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

class _CharacterThumbnail extends StatelessWidget {
  const _CharacterThumbnail({required this.character, required this.owned});

  final CosmeticItem character;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      character.characterVisuals!.idle,
      key: ValueKey<String>('solo-character-art-${character.id}'),
      fit: BoxFit.contain,
      cacheWidth: 240,
    );
    if (owned) return image;

    return Opacity(
      opacity: 0.72,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      ),
    );
  }
}

class _StartSoloButton extends StatelessWidget {
  const _StartSoloButton({required this.onPressed});

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
                color: const Color(0xFFF09A4B),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 7,
            child: Material(
              color: const Color(0xFFFFD49B),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('solo-start-preview'),
                onTap: onPressed,
                child: Center(
                  child: Text(
                    'MULAI LATIHAN',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFB85C1E),
                      fontSize: 14,
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

class _MissingSoloSetup extends StatelessWidget {
  const _MissingSoloSetup({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.tune_rounded,
                color: AppColors.warriorNavy,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih jenis sesi Solo terlebih dahulu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.warriorNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: onBack, child: const Text('Kembali')),
            ],
          ),
        ),
      ),
    );
  }
}

String _arenaIdForMode(SoloSetupMode mode) => switch (mode) {
  SoloSetupMode.auto => GameEconomyCatalog.defaultArenaId,
  SoloSetupMode.balanced => 'arena-rimba-yudha',
  SoloSetupMode.recommended => 'arena-lembah-bara',
  SoloSetupMode.custom => 'arena-gurun-cendekia',
};

String _modeLabel(SoloSetupMode mode) => switch (mode) {
  SoloSetupMode.auto => 'Auto',
  SoloSetupMode.balanced => 'Seimbang',
  SoloSetupMode.recommended => 'Rekomendasi',
  SoloSetupMode.custom => 'Pilih topik',
};

Color _accentForMode(SoloSetupMode mode) => switch (mode) {
  SoloSetupMode.auto => const Color(0xFF2878F0),
  SoloSetupMode.balanced => const Color(0xFF20A778),
  SoloSetupMode.recommended => const Color(0xFFF08A36),
  SoloSetupMode.custom => const Color(0xFFB24EA6),
};

String _mechanicLabel(SoloMechanicMode mode) => switch (mode) {
  SoloMechanicMode.focus => 'Focus',
  SoloMechanicMode.standard => 'Standard',
  SoloMechanicMode.speed => 'Speed',
};

String _mechanicDescription(SoloMechanicMode mode) => switch (mode) {
  SoloMechanicMode.focus => 'Tanpa batas waktu',
  SoloMechanicMode.standard => 'Waktu normal per soal',
  SoloMechanicMode.speed => 'Tantangan kecepatan',
};

IconData _mechanicIcon(SoloMechanicMode mode) => switch (mode) {
  SoloMechanicMode.focus => Icons.self_improvement_rounded,
  SoloMechanicMode.standard => Icons.timer_outlined,
  SoloMechanicMode.speed => Icons.bolt_rounded,
};
