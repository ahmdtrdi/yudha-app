part of '../pvp_page.dart';

class _QuestionBattleSheet extends StatefulWidget {
  const _QuestionBattleSheet({
    required this.question,
    required this.onAnswered,
    required this.isOnline,
  });

  final BattleQuestion question;
  final Future<bool> Function(int selectedOptionIndex) onAnswered;
  final bool isOnline;

  @override
  State<_QuestionBattleSheet> createState() => _QuestionBattleSheetState();
}

class _QuestionBattleSheetState extends State<_QuestionBattleSheet> {
  static const int _maxSeconds = 10;
  static const Color _ink = Color(0xFF17233F);
  static const Color _warmCanvas = Color(0xFFFFF8EC);
  static const Color _mutedInk = Color(0xFF66708A);
  static const Color _success = Color(0xFF2FAE7D);
  static const Color _danger = Color(0xFFF05E5E);

  Timer? _timer;
  int _remainingSeconds = _maxSeconds;
  int? _selectedIndex;
  bool _locked = false;
  bool _allowPop = false;
  bool? _isCorrect;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitAnswer(-1, timedOut: true);
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submitAnswer(int selectedIndex, {bool timedOut = false}) async {
    if (_locked) {
      return;
    }

    final bool isDamage = widget.question.effect == QuestionEffect.damage;
    final int? correctOptionIndex = widget.question.correctOptionIndex;
    final bool? correct = correctOptionIndex == null
        ? null
        : selectedIndex == correctOptionIndex;
    _timer?.cancel();
    setState(() {
      _locked = true;
      if (timedOut) {
        _remainingSeconds = 0;
      }
      _selectedIndex = selectedIndex;
      _isCorrect = timedOut ? false : correct;
      _feedback = timedOut
          ? 'Waktu habis. Kartu tidak digunakan.'
          : correct == null
          ? 'Jawaban dikirim ke arena.'
          : correct
          ? isDamage
                ? 'Tepat! Serangan diluncurkan.'
                : 'Tepat! Pertahananmu pulih.'
          : isDamage
          ? 'Belum tepat. Lawan mendapat giliran balasan.'
          : 'Belum tepat. Lawan mendapat pemulihan.';
    });

    await Future<void>.delayed(
      Duration(milliseconds: widget.isOnline ? 180 : 520),
    );
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
    final int impact = BattleStateMachine.impactFromWeight(
      widget.question.weight,
    );
    final double timerProgress = _remainingSeconds / _maxSeconds;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return PopScope(
      canPop: !widget.isOnline || _allowPop,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
            decoration: BoxDecoration(
              color: _warmCanvas,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: categoryColor.withAlpha(60)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _ink.withAlpha(48),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
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
                  Row(
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
                              widget.isOnline
                                  ? '${isDamage ? 'Serang' : 'Pulihkan'}  |  Power ${widget.question.weight.clamp(1, 3)}/3'
                                  : '${isDamage ? 'Serang' : 'Pulihkan'}  |  $impact dampak',
                              style: GoogleFonts.dmSans(
                                color: _mutedInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isOnline) ...<Widget>[
                        const SizedBox(width: 10),
                        _TimerRing(
                          remainingSeconds: _remainingSeconds,
                          progress: timerProgress,
                          accent: categoryColor,
                        ),
                      ] else ...<Widget>[
                        const SizedBox(width: 10),
                        const _ServerBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: categoryColor.withAlpha(48)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _ink.withAlpha(12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                      correct: widget.question.correctOptionIndex == index,
                      revealResult:
                          !widget.isOnline &&
                          _locked &&
                          widget.question.correctOptionIndex != null,
                      enabled: !_locked,
                      onTap: () => _submitAnswer(index),
                    ),
                    if (index != widget.question.options.length - 1)
                      const SizedBox(height: 8),
                  ],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F1FF),
                        borderRadius: BorderRadius.circular(14),
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
      'tiu' || 'numerik' => 'Numerik',
      'verbal' => 'Verbal',
      'logika' => 'Logika',
      'twk' => 'TWK',
      _ => category.trim().isEmpty ? 'Kartu soal' : category.trim(),
    };
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
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withAlpha(45),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
    final Color borderColor = showCorrect
        ? success
        : selectedWrong
        ? danger
        : selected
        ? categoryColor
        : ink.withAlpha(28);
    final Color background = showCorrect
        ? const Color(0xFFE9F8F1)
        : selectedWrong
        ? const Color(0xFFFFEEEE)
        : selected
        ? categoryColor.withAlpha(18)
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

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: 'Jawaban $optionLetter, $text',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 2 : 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(15),
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
        color: color.withAlpha(18),
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

class _ServerBadge extends StatelessWidget {
  const _ServerBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jawaban diverifikasi server',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F1FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.cloud_done_rounded,
          color: Color(0xFF2878F0),
          size: 24,
        ),
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
      child: SizedBox(
        width: 48,
        height: 48,
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
