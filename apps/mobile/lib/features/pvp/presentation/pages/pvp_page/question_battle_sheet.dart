part of '../pvp_page.dart';

class _QuestionBattleSheet extends StatefulWidget {
  const _QuestionBattleSheet({
    required this.question,
    required this.onAnswered,
    required this.isOnline,
    required this.comboLevel,
    required this.soundEnabled,
    required this.hapticsEnabled,
  });

  final BattleQuestion question;
  final Future<bool> Function(int selectedOptionIndex) onAnswered;
  final bool isOnline;
  final int comboLevel;
  final bool soundEnabled;
  final bool hapticsEnabled;

  @override
  State<_QuestionBattleSheet> createState() => _QuestionBattleSheetState();
}

class _QuestionBattleSheetState extends State<_QuestionBattleSheet> {
  static const Color _ink = _BattleClayPalette.ink;
  static const Color _mutedInk = _BattleClayPalette.mutedInk;
  static const Color _success = Color(0xFF2FAE7D);
  static const Color _danger = Color(0xFFF05E5E);

  Timer? _timer;
  late final ArenaAudioController _sfx = ArenaAudioController.sfxOnly(
    enabled: widget.soundEnabled,
  );
  late final GameHaptics _haptics = GameHaptics(widget.hapticsEnabled);
  late final int _maxSeconds;
  late int _remainingSeconds;
  int? _selectedIndex;
  bool _locked = false;
  bool _allowPop = false;
  bool? _isCorrect;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _maxSeconds = widget.question.timeLimitSeconds.clamp(1, 300);
    _remainingSeconds = _maxSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (widget.isOnline) {
          if (mounted) {
            setState(() {
              _remainingSeconds = 0;
              _locked = true;
              _feedback = 'Waktu habis. Menunggu konfirmasi arena...';
            });
          }
        } else {
          _submitAnswer(-1, timedOut: true);
        }
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
      if (_remainingSeconds <= 3) {
        _sfx.playTickdown();
        _haptics.light();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_sfx.dispose());
    super.dispose();
  }

  Future<void> _submitAnswer(int selectedIndex, {bool timedOut = false}) async {
    if (_locked) {
      return;
    }

    final int? correctOptionIndex = widget.question.correctOptionIndex;
    final bool? correct = correctOptionIndex == null
        ? null
        : selectedIndex == correctOptionIndex;
    _timer?.cancel();
    if (timedOut) {
      _haptics.vibrate();
      _sfx.playAnswerWrong();
    } else if (correct == true) {
      _haptics.light();
      _sfx.playAnswerCorrect();
    } else if (correct == false) {
      _haptics.medium();
      _sfx.playAnswerWrong();
    } else {
      _haptics.light();
    }
    setState(() {
      _locked = true;
      if (timedOut) {
        _remainingSeconds = 0;
      }
      _selectedIndex = selectedIndex;
      _isCorrect = timedOut ? false : correct;
      _feedback = timedOut ? 'Waktu habis. Kartu tidak digunakan.' : null;
    });

    if (timedOut) {
      await Future<void>.delayed(const Duration(milliseconds: 520));
    }
    if (!mounted) {
      return;
    }

    final bool submitted = await widget.onAnswered(selectedIndex);
    if (!mounted) {
      return;
    }
    if (!submitted) {
      setState(() {
        _locked = false;
        _selectedIndex = null;
        _isCorrect = null;
        _feedback = 'Jawaban belum terkirim. Coba pilih lagi.';
      });
      return;
    }

    setState(() {
      _allowPop = true;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDamage = widget.question.effect == QuestionEffect.damage;
    final Color categoryColor = _categoryColor(widget.question.category);
    final int comboLevel = widget.comboLevel.clamp(1, 3);
    final int impact = BattleStateMachine.effectFromCombo(comboLevel);
    final String? subcategoryLabel = _subcategoryLabel(
      widget.question.subcategory,
    );
    final double timerProgress = _remainingSeconds / _maxSeconds;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !widget.isOnline || _allowPop,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: BattleQuestionSheetFrame(
            sheetKey: const ValueKey<String>('question-battle-sheet'),
            accent: categoryColor,
            child: SingleChildScrollView(
              key: const ValueKey<String>('question-sheet-scroll-view'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _ink.withAlpha(28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    key: const ValueKey<String>('question-sheet-header'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        categoryColor.withAlpha(20),
                        Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: categoryColor.withAlpha(52)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _QuestionEmblem(
                          color: categoryColor,
                          icon: _categoryIcon(widget.question.category),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _categoryLabel(widget.question.category),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.fredoka(
                                  color: _ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                <String>[
                                  ?subcategoryLabel,
                                  isDamage ? 'Serang' : 'Pulihkan',
                                  'Combo x$comboLevel',
                                  '$impact dampak',
                                ].join('  |  '),
                                style: GoogleFonts.dmSans(
                                  color: _mutedInk,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TimerRing(
                          remainingSeconds: _remainingSeconds,
                          progress: timerProgress,
                          accent: categoryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    key: const ValueKey<String>('question-prompt-card'),
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: categoryColor.withAlpha(48)),
                    ),
                    child: Text(
                      widget.question.prompt,
                      style: GoogleFonts.dmSans(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pilih jawaban',
                    style: GoogleFonts.dmSans(
                      color: _mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const ValueKey<String>('question-answer-group'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _ink.withAlpha(24)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xFFD9DEE7),
                          blurRadius: 0,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < widget.question.options.length;
                          index++
                        ) ...<Widget>[
                          _AnswerOption(
                            index: index,
                            text: widget.question.options[index],
                            categoryColor: categoryColor,
                            selected: _selectedIndex == index,
                            correct:
                                widget.question.correctOptionIndex == index,
                            revealResult:
                                !widget.isOnline &&
                                _locked &&
                                widget.question.correctOptionIndex != null,
                            enabled: !_locked,
                            onTap: () => _submitAnswer(index),
                          ),
                          if (index != widget.question.options.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 12,
                              endIndent: 12,
                              color: _ink.withAlpha(16),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _feedback == null
                        ? const SizedBox(height: 0)
                        : _QuestionFeedback(
                            key: ValueKey<String>(_feedback!),
                            text: _feedback!,
                            state: _isCorrect,
                          ),
                  ),
                  if (_feedback != null) const SizedBox(height: 8),
                  if (widget.isOnline)
                    Container(
                      key: const ValueKey<String>('question-online-status'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F1FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF2878F0).withAlpha(45),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.cloud_done_rounded,
                            color: Color(0xFF2878F0),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kartu sudah dibuka online. Pilih satu jawaban untuk melanjutkan.',
                              style: GoogleFonts.dmSans(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: _locked
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _mutedInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Kembali ke kartu',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
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
    );
  }

  Color _categoryColor(String category) {
    return switch (category.trim().toLowerCase()) {
      'verbal' => const Color(0xFF8B6FE8),
      'logika' => const Color(0xFFFF9F43),
      'twk' => const Color(0xFF47CFA0),
      _ => const Color(0xFF2878F0),
    };
  }

  String _categoryLabel(String category) {
    return switch (category.trim().toLowerCase()) {
      'tiu' => 'TIU',
      'tkp' => 'TKP',
      'twk' => 'TWK',
      'wk' => 'WK',
      'tkd' => 'TKD',
      'akhlak' => 'AKHLAK',
      'wawasan_kebangsaan' => 'Wawasan Kebangsaan',
      'numerik' => 'Numerik',
      'verbal' => 'Verbal',
      'logika' => 'Logika',
      _ => category.trim().isEmpty ? 'Kartu soal' : category.trim(),
    };
  }

  String? _subcategoryLabel(String? subcategory) {
    final String normalized = subcategory?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  IconData _categoryIcon(String category) {
    return switch (category.trim().toLowerCase()) {
      'verbal' => Icons.forum_rounded,
      'logika' => Icons.extension_rounded,
      'twk' => Icons.shield_rounded,
      _ => Icons.calculate_rounded,
    };
  }
}

class _QuestionEmblem extends StatelessWidget {
  const _QuestionEmblem({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.text,
    required this.categoryColor,
    required this.selected,
    required this.correct,
    required this.revealResult,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final Color categoryColor;
  final bool selected;
  final bool correct;
  final bool revealResult;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color ink = Color(0xFF17233F);
    const Color success = Color(0xFF2FAE7D);
    const Color danger = Color(0xFFF05E5E);
    final bool selectedWrong = revealResult && selected && !correct;
    final bool showCorrect = revealResult && correct;
    final bool subdued = !enabled && !selected && !showCorrect;
    final Color borderColor = showCorrect
        ? success
        : selectedWrong
        ? danger
        : selected
        ? categoryColor
        : Colors.transparent;
    final Color background = showCorrect
        ? const Color(0xFFE9F8F1)
        : selectedWrong
        ? const Color(0xFFFFEEEE)
        : selected
        ? categoryColor.withAlpha(18)
        : subdued
        ? const Color(0xFFF1EFE9)
        : Colors.white;
    final Color markerColor = showCorrect
        ? success
        : selectedWrong
        ? danger
        : selected
        ? categoryColor
        : const Color(0xFFF0F2F7);
    final Color markerTextColor = selected || showCorrect || selectedWrong
        ? Colors.white
        : const Color(0xFF66708A);
    final String optionLetter = String.fromCharCode(65 + index);
    final bool highlighted = selected || showCorrect || selectedWrong;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: 'Jawaban $optionLetter, $text',
      child: AnimatedContainer(
        key: ValueKey<String>('question-answer-$index'),
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor, width: highlighted ? 1.5 : 0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: showCorrect
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : selectedWrong
                        ? const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            optionLetter,
                            style: GoogleFonts.fredoka(
                              color: markerTextColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.dmSans(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionFeedback extends StatelessWidget {
  const _QuestionFeedback({
    required super.key,
    required this.text,
    required this.state,
  });

  final String text;
  final bool? state;

  @override
  Widget build(BuildContext context) {
    final Color color = state == true
        ? _QuestionBattleSheetState._success
        : state == false
        ? _QuestionBattleSheetState._danger
        : const Color(0xFF2878F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withAlpha(18), Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            state == true
                ? Icons.check_circle_rounded
                : state == false
                ? Icons.info_rounded
                : Icons.send_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: _QuestionBattleSheetState._ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.remainingSeconds,
    required this.progress,
    required this.accent,
  });

  final int remainingSeconds;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final Color color = remainingSeconds <= 3
        ? const Color(0xFFF05E5E)
        : accent;

    return Semantics(
      label: 'Sisa waktu',
      value: '$remainingSeconds detik',
      child: Container(
        key: const ValueKey<String>('question-timer-ring'),
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(52)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: _QuestionBattleSheetState._ink.withAlpha(18),
            ),
            Text(
              '$remainingSeconds',
              style: GoogleFonts.fredoka(
                color: _QuestionBattleSheetState._ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
