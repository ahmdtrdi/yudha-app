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
      return _MissingSession(message: state.error);
    }
    if (!session.isActive && !state.showFeedback) {
      return _SoloResult(
        session: session,
        onExit: () {
          ref.invalidate(activeSoloSessionProvider);
          context.go(AppRoutes.solo);
        },
      );
    }

    final character = GameEconomyCatalog.characters.firstWhere(
      (item) => item.id == session.characterId,
      orElse: () => GameEconomyCatalog.characters.first,
    );
    String? activeQuestionId = state.openedQuestion?.sessionQuestionId;
    for (final card in session.hand) {
      if (card.openedAt != null) activeQuestionId ??= card.sessionQuestionId;
    }
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _ArenaStage(
            session: session,
            character: character,
            reaction: state.reaction,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: <Widget>[
                  _BattleStatus(
                    session: session,
                    submitting: state.submitting,
                    onStop: () => _confirmStop(context, controller),
                  ),
                  const Spacer(),
                  _CardTray(
                    hand: session.hand,
                    loading: state.submitting,
                    activeQuestionId: activeQuestionId,
                    onOpen: controller.openCard,
                  ),
                  if (state.error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _ErrorBanner(state.error!),
                  ],
                ],
              ),
            ),
          ),
          if (state.questionVisible && state.openedQuestion != null)
            _QuestionOverlay(
              question: state.openedQuestion!,
              feedback: state.feedback,
              selectedOption: state.selectedOption,
              hintVisible: state.hintVisible,
              submitting: state.submitting,
              onSelect: controller.selectAndSubmit,
              onHint: controller.showHint,
              onTimeout: controller.timeout,
              onBack: controller.closeQuestion,
              onNext: controller.next,
            ),
        ],
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

class _ArenaStage extends StatelessWidget {
  const _ArenaStage({
    required this.session,
    required this.character,
    required this.reaction,
  });

  final SoloSession session;
  final CosmeticItem character;
  final SoloReaction reaction;

  @override
  Widget build(BuildContext context) {
    final tower = GameEconomyCatalog.towers.first;
    final visuals = character.characterVisuals!;
    final characterAsset = switch (reaction) {
      SoloReaction.attack => visuals.attack,
      SoloReaction.hit => visuals.hit,
      SoloReaction.idle => visuals.ready,
    };
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset('assets/game/arena_rimba_yudha.png', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x22002467),
                Color(0x0014213A),
                Color(0x6614213A),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 82,
          left: 0,
          right: 0,
          height: 145,
          child: Image.asset(
            session.towerHp == 0
                ? tower.destroyedAssetPath!
                : tower.battleAssetPath!,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 158,
          height: 245,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Image.asset(
              characterAsset,
              key: ValueKey<String>(characterAsset),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

class _BattleStatus extends StatelessWidget {
  const _BattleStatus({
    required this.session,
    required this.submitting,
    required this.onStop,
  });
  final SoloSession session;
  final bool submitting;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.scholarCream,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0xFFC8D0DC), offset: Offset(0, 5)),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFFFDFDF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.castle_rounded,
            color: Color(0xFFEF5B62),
            size: 20,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'TOWER',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${session.towerHp} HP',
                    style: const TextStyle(
                      color: Color(0xFFEF5B62),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: session.towerHp / 100,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFFFE2E2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFEF5B62)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF123A69),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${session.answeredCount}/${session.questionCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 7),
        IconButton(
          key: const ValueKey<String>('solo-stop'),
          onPressed: submitting ? null : onStop,
          icon: const Icon(Icons.pause_rounded),
          color: AppColors.warriorNavy,
          style: IconButton.styleFrom(backgroundColor: Colors.white),
        ),
      ],
    ),
  );
}

class _CardTray extends StatelessWidget {
  const _CardTray({
    required this.hand,
    required this.loading,
    required this.activeQuestionId,
    required this.onOpen,
  });
  final List<SoloHandCard> hand;
  final bool loading;
  final String? activeQuestionId;
  final ValueChanged<SoloHandCard> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.scholarCream,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0xFFC7CFDA), offset: Offset(0, 6)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Pilih kartu',
              style: GoogleFonts.fredoka(
                fontWeight: FontWeight.w800,
                color: AppColors.warriorNavy,
              ),
            ),
            const Spacer(),
            Text(
              activeQuestionId == null
                  ? 'Jawab untuk menyerang'
                  : 'Timer kartu tetap berjalan',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: Wrap(
              key: ValueKey<int>(hand.length),
              spacing: 10,
              alignment: WrapAlignment.center,
              children: hand
                  .map((card) {
                    final isActive = activeQuestionId == card.sessionQuestionId;
                    return InkWell(
                      key: ValueKey<String>(
                        'solo-card-${card.sessionQuestionId}',
                      ),
                      onTap: loading ? null : () => onOpen(card),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 68,
                        height: 96,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF2878F0)
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0xFFB9C2D1),
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(_cardAsset(card), fit: BoxFit.cover),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2878F0),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${card.questionOrder}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    ),
  );
}

String _cardAsset(SoloHandCard card) {
  final value = '${card.category} ${card.subcategory}'.toLowerCase();
  if (value.contains('twk')) return 'assets/game/card_twk.png';
  if (value.contains('akhlak')) return 'assets/game/card_akhlak.png';
  if (value.contains('tkp')) return 'assets/game/card_tkp.png';
  if (value.contains('figural')) return 'assets/game/card_figural.png';
  if (value.contains('numerik')) return 'assets/game/card_numerik.png';
  if (value.contains('verbal')) return 'assets/game/card_verbal.png';
  return 'assets/game/card_logika.png';
}

class _QuestionOverlay extends StatelessWidget {
  const _QuestionOverlay({
    required this.question,
    required this.feedback,
    required this.selectedOption,
    required this.hintVisible,
    required this.submitting,
    required this.onSelect,
    required this.onHint,
    required this.onTimeout,
    required this.onBack,
    required this.onNext,
  });
  final SoloQuestion question;
  final SoloAnswerFeedback? feedback;
  final int? selectedOption;
  final bool hintVisible;
  final bool submitting;
  final Future<void> Function(int) onSelect;
  final VoidCallback onHint;
  final VoidCallback onTimeout;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final answered = feedback != null;
    return ColoredBox(
      color: const Color(0x6609162D),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.76,
          widthFactor: 1,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.scholarCream,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0xFFB8C0CD), offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.fireGold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.extension_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              question.category.toUpperCase(),
                              style: GoogleFonts.fredoka(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Soal ${question.questionOrder}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!answered && question.deadlineAt != null)
                        _DeadlineTimer(
                          key: ValueKey<DateTime>(question.deadlineAt!),
                          deadline: question.deadlineAt!,
                          onTimeout: onTimeout,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0xFFD7D9DC),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            question.prompt,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!answered)
                          hintVisible
                              ? _Hint(
                                  text: question.hint.isEmpty
                                      ? 'Petunjuk belum tersedia untuk soal ini.'
                                      : question.hint,
                                )
                              : OutlinedButton.icon(
                                  key: const ValueKey<String>('solo-show-hint'),
                                  onPressed: onHint,
                                  icon: const Icon(
                                    Icons.help_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Lihat petunjuk'),
                                ),
                        if (!answered) const SizedBox(height: 10),
                        for (
                          int index = 0;
                          index < question.options.length;
                          index++
                        ) ...<Widget>[
                          _Option(
                            index: index,
                            label: question.options[index],
                            selected: selectedOption == index,
                            feedback: answered,
                            correctIndex: feedback?.correctOptionIndex,
                            onTap: () => onSelect(index),
                          ),
                          const SizedBox(height: 9),
                        ],
                        if (answered && feedback!.explanation.isNotEmpty)
                          _Explanation(text: feedback!.explanation),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    14 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          key: const ValueKey<String>('solo-session-action'),
                          onPressed: submitting || !answered ? null : onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: answered
                                ? const Color(0xFF2878F0)
                                : AppColors.fireGold,
                            foregroundColor: answered
                                ? Colors.white
                                : AppColors.warriorNavy,
                          ),
                          child: submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  answered ? 'LANJUT' : 'PILIH JAWABAN',
                                  style: GoogleFonts.fredoka(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      if (!answered && !submitting)
                        TextButton(
                          onPressed: submitting ? null : onBack,
                          child: const Text('Kembali ke kartu'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.fireGold, width: 2),
    ),
    child: Text(
      '$remaining',
      style: const TextStyle(fontWeight: FontWeight.w900),
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
    final color = correct
        ? const Color(0xFF20A778)
        : wrong
        ? const Color(0xFFEF5B62)
        : selected
        ? const Color(0xFF2878F0)
        : const Color(0xFFE0E3E8);
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
            border: Border.all(color: color),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected || correct ? color : const Color(0xFFF0F3F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: selected || correct
                        ? Colors.white
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFDF7E7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.fireGold),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.info_outline, color: AppColors.fireGold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
        ),
      ],
    ),
  );
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF2878F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'PEMBAHASAN',
          style: TextStyle(
            color: Color(0xFF2878F0),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE2E2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFB7353B),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MissingSession extends StatelessWidget {
  const _MissingSession({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scholarCream,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message ?? 'Sesi Solo belum dimulai.',
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

class _SoloResult extends StatelessWidget {
  const _SoloResult({required this.session, required this.onExit});
  final SoloSession session;
  final VoidCallback onExit;
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
                  onPressed: onExit,
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
