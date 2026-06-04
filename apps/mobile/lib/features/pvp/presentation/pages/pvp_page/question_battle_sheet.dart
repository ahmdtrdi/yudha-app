part of '../pvp_page.dart';

class _QuestionBattleSheet extends StatefulWidget {
  const _QuestionBattleSheet({
    required this.question,
    required this.onAnswered,
  });

  final BattleQuestion question;
  final ValueChanged<int> onAnswered;

  @override
  State<_QuestionBattleSheet> createState() => _QuestionBattleSheetState();
}

class _QuestionBattleSheetState extends State<_QuestionBattleSheet> {
  static const int _maxSeconds = 10;

  Timer? _timer;
  int _remainingSeconds = _maxSeconds;
  int? _selectedIndex;
  bool _locked = false;
  bool? _isCorrect;
  String? _feedback;

  @override
  void initState() {
    super.initState();
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

    final bool correct = selectedIndex == widget.question.correctOptionIndex;
    _timer?.cancel();
    setState(() {
      _locked = true;
      _selectedIndex = selectedIndex;
      _isCorrect = correct;
      _feedback = timedOut
          ? 'Waktu habis. Serangan gagal.'
          : correct
          ? 'Jawaban benar. Serangan masuk.'
          : 'Jawaban kurang tepat. Lawan membalas.';
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) {
      return;
    }

    widget.onAnswered(selectedIndex);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDamage = widget.question.effect == QuestionEffect.damage;
    final Color accent = isDamage
        ? const Color(0xFF3EAAFF)
        : const Color(0xFF2ECC6A);
    final int impact = BattleStateMachine.impactFromWeight(
      widget.question.weight,
    );
    final double timerProgress = _remainingSeconds / _maxSeconds;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF141440), Color(0xFF080A22)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: accent, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(170),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              _QuestionBadge(
                                text: isDamage ? 'SERANGAN' : 'HEAL',
                                color: accent,
                              ),
                              _QuestionBadge(
                                text: '$impact POWER',
                                color: AppColors.fireGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Jawab untuk ${isDamage ? 'menyerang' : 'memulihkan'}',
                            style: GoogleFonts.orbitron(
                              color: AppColors.fireGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TimerRing(
                      remainingSeconds: _remainingSeconds,
                      progress: timerProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.question.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool singleColumn = constraints.maxWidth < 340;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.question.options.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: singleColumn ? 1 : 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: singleColumn ? 4.2 : 2.9,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final bool isSelected = _selectedIndex == index;
                        final bool optionCorrect =
                            index == widget.question.correctOptionIndex;
                        Color border = Colors.white.withAlpha(46);
                        Color background = Colors.white.withAlpha(16);
                        Color textColor = Colors.white;

                        if (_locked && isSelected) {
                          border = optionCorrect
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171);
                          background = optionCorrect
                              ? const Color(0xFF22C55E).withAlpha(55)
                              : const Color(0xFFEF4444).withAlpha(46);
                          textColor = border;
                        }

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _locked ? null : () => _submitAnswer(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  widget.question.options[index],
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _feedback == null
                      ? const SizedBox(height: 20)
                      : Text(
                          _feedback!,
                          key: ValueKey<String>(_feedback!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isCorrect == true
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
                if (widget.question.weight == 3) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fireGold.withAlpha(32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Power round: kartu ini memberi impact terbesar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFCD34D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _locked ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withAlpha(120),
                    side: BorderSide(color: Colors.white.withAlpha(34)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionBadge extends StatelessWidget {
  const _QuestionBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.remainingSeconds, required this.progress});

  final int remainingSeconds;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final Color color = remainingSeconds <= 3
        ? const Color(0xFFF87171)
        : const Color(0xFF22C55E);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: Colors.white.withAlpha(22),
          ),
          Text(
            '$remainingSeconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
