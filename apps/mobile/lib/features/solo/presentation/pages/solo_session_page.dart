import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_providers.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

class SoloSessionPage extends ConsumerWidget {
  const SoloSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(soloSessionControllerProvider);
    final controller = ref.read(soloSessionControllerProvider.notifier);
    final session = state.session;
    if (state.loading) {
      return const Scaffold(
        backgroundColor: AppColors.scholarCream,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.scholarCream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  state.error ?? 'Sesi Solo belum dimulai.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.solo),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!session.isActive) return _SoloResult(session: session);

    final question = state.showFeedback
        ? session.questions[session.answeredCount - 1]
        : session.currentQuestion!;
    final character = GameEconomyCatalog.characters.firstWhere(
      (item) => item.id == session.characterId,
      orElse: () => GameEconomyCatalog.characters.first,
    );
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D49B5),
        foregroundColor: Colors.white,
        title: Text(
          'SOAL ${question.questionOrder}/${session.questionCount}',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('solo-stop'),
            icon: const Icon(Icons.flag_rounded),
            onPressed: state.submitting
                ? null
                : () => _confirmStop(context, controller),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _Arena(
              session: session,
              character: character,
              reaction: state.reaction,
              deadline: question.deadlineAt,
              timerEnabled: !state.showFeedback,
              onTimeout: controller.timeout,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      question.category.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF2878F0),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      question.prompt,
                      style: GoogleFonts.fredoka(
                        color: AppColors.warriorNavy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (
                      int index = 0;
                      index < question.options.length;
                      index++
                    ) ...<Widget>[
                      _Option(
                        index: index,
                        label: question.options[index],
                        selected: state.selectedOption == index,
                        feedback: state.showFeedback,
                        correctIndex: state.showFeedback
                            ? question.correctOptionIndex
                            : null,
                        onTap: () => controller.select(index),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (state.showFeedback &&
                        (question.explanation ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          question.explanation!,
                          style: const TextStyle(fontSize: 12, height: 1.35),
                        ),
                      ),
                    if (state.error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey<String>('solo-session-action'),
                  onPressed: state.submitting
                      ? null
                      : state.showFeedback
                      ? controller.next
                      : state.selectedOption == null
                      ? null
                      : controller.submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: state.showFeedback
                        ? const Color(0xFF2878F0)
                        : AppColors.fireGold,
                    foregroundColor: state.showFeedback
                        ? Colors.white
                        : AppColors.warriorNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: state.submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          state.showFeedback ? 'LANJUT' : 'JAWAB',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStop(
    BuildContext context,
    SoloSessionController controller,
  ) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akhiri latihan?'),
        content: const Text(
          'Jawabanmu tetap tercatat, tetapi sesi ini tidak memberikan hadiah.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut latihan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (stop == true) await controller.stop();
  }
}

class _Arena extends StatelessWidget {
  const _Arena({
    required this.session,
    required this.character,
    required this.reaction,
    required this.deadline,
    required this.timerEnabled,
    required this.onTimeout,
  });
  final SoloSession session;
  final CosmeticItem character;
  final SoloReaction reaction;
  final DateTime? deadline;
  final bool timerEnabled;
  final VoidCallback onTimeout;

  @override
  Widget build(BuildContext context) {
    final tower = GameEconomyCatalog.towers.first;
    final visuals = character.characterVisuals!;
    final characterAsset = switch (reaction) {
      SoloReaction.attack => visuals.attack,
      SoloReaction.hit => visuals.hit,
      SoloReaction.idle => visuals.ready,
    };
    return SizedBox(
      height: 225,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/game/arena_rimba_yudha.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x0014213A), Color(0x9914213A)],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: session.towerHp / 100,
                          minHeight: 13,
                          backgroundColor: Colors.white70,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFEF5B62),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${session.towerHp} HP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (deadline != null && timerEnabled) ...<Widget>[
                  const SizedBox(height: 6),
                  _DeadlineTimer(
                    key: ValueKey<DateTime>(deadline!),
                    deadline: deadline!,
                    onTimeout: onTimeout,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 28,
            bottom: 10,
            width: 120,
            height: 150,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Image.asset(
                characterAsset,
                key: ValueKey<String>(characterAsset),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: 25,
            bottom: 12,
            width: 125,
            height: 150,
            child: Image.asset(
              session.towerHp == 0
                  ? tower.destroyedAssetPath!
                  : tower.battleAssetPath!,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineTimer extends StatefulWidget {
  const _DeadlineTimer({
    super.key,
    required this.deadline,
    required this.onTimeout,
  });
  final DateTime deadline;
  final VoidCallback onTimeout;
  @override
  State<_DeadlineTimer> createState() => _DeadlineTimerState();
}

class _DeadlineTimerState extends State<_DeadlineTimer> {
  Timer? timer;
  late int remaining;
  bool fired = false;
  @override
  void initState() {
    super.initState();
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final value = widget.deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 999);
    if (mounted) setState(() => remaining = value);
    if (value == 0 && !fired) {
      fired = true;
      timer?.cancel();
      widget.onTimeout();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '$remaining detik',
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 11,
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.index,
    required this.label,
    required this.selected,
    required this.feedback,
    required this.correctIndex,
    required this.onTap,
  });
  final int index;
  final String label;
  final bool selected;
  final bool feedback;
  final int? correctIndex;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final correct = feedback && index == correctIndex;
    final wrong = feedback && selected && !correct;
    return Material(
      color: correct
          ? const Color(0xFFDDF7E8)
          : wrong
          ? const Color(0xFFFFE2E2)
          : selected
          ? const Color(0xFFE5EEFF)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('solo-option-$index'),
        onTap: feedback ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: correct
                  ? const Color(0xFF20A778)
                  : wrong
                  ? const Color(0xFFEF5B62)
                  : selected
                  ? const Color(0xFF2878F0)
                  : const Color(0xFFE0E3E8),
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                String.fromCharCode(65 + index),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoloResult extends StatelessWidget {
  const _SoloResult({required this.session});
  final SoloSession session;
  @override
  Widget build(BuildContext context) {
    final destroyed = session.completionReason == 'tower_destroyed';
    final stopped = session.completionReason == 'user_stopped';
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                destroyed
                    ? Icons.emoji_events_rounded
                    : stopped
                    ? Icons.flag_rounded
                    : Icons.insights_rounded,
                size: 76,
                color: destroyed ? AppColors.fireGold : const Color(0xFF2878F0),
              ),
              const SizedBox(height: 18),
              Text(
                destroyed
                    ? 'MENARA RUNTUH!'
                    : stopped
                    ? 'LATIHAN DIAKHIRI'
                    : 'SESI SELESAI',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: AppColors.warriorNavy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${session.correctCount}/${session.questionCount} benar · ${session.towerHp} HP tersisa',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0xFFD5D9E0), offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    const Text(
                      'HADIAH SOLO',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${session.rewardCoins} Y-Coin',
                      style: GoogleFonts.fredoka(
                        color: AppColors.fireGold,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.solo),
                  child: const Text('LATIHAN LAGI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
