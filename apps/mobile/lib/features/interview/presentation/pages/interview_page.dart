import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

class InterviewPage extends ConsumerStatefulWidget {
  const InterviewPage({required this.config, super.key});

  final InterviewLaunchConfig config;

  @override
  ConsumerState<InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends ConsumerState<InterviewPage> {
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interviewControllerProvider(widget.config).notifier).start();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final String answer = _answerController.text.trim();
    if (answer.isEmpty) {
      return;
    }

    _answerController.clear();
    await ref
        .read(interviewControllerProvider(widget.config).notifier)
        .submitAnswer(answer);
    _scrollToBottom();
  }

  Future<void> _completeSession() async {
    await ref
        .read(interviewControllerProvider(widget.config).notifier)
        .complete();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showHistory(InterviewState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.scholarCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _SessionsSheet(
          currentSessionId: state.sessionId,
          config: widget.config,
          onOpenSession: (InterviewSessionSummaryRecord session) {
            Navigator.of(context).pop();
            _showSessionDetail(session.sessionId);
          },
        );
      },
    );
  }

  void _showSessionDetail(String sessionId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.scholarCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _SessionDetailSheet(sessionId: sessionId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final InterviewState state = ref.watch(
      interviewControllerProvider(widget.config),
    );
    final bool isBusy =
        state.status == InterviewViewStatus.starting ||
        state.status == InterviewViewStatus.submitting;
    final bool isVoiceMode = widget.config.responseStyle == 'voice';
    final InterviewMessage? currentQuestion = state.currentQuestion;
    final InterviewMessage? latestCandidateAnswer = _latestMessageByAuthor(
      state.messages,
      InterviewMessageAuthor.candidate,
    );

    ref.listen<InterviewState>(interviewControllerProvider(widget.config), (
      InterviewState? previous,
      InterviewState next,
    ) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.warriorNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: <Widget>[
            Text(
              'INTERVIEW AI',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.config.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Riwayat chat',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistory(state),
          ),
          TextButton(
            onPressed: isBusy ? null : _completeSession,
            child: const Text(
              'Selesai',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (!isVoiceMode || state.status == InterviewViewStatus.completed)
              _InterviewHeader(
                status: state.status,
                config: widget.config,
                currentQuestion: currentQuestion,
                finalSummary: state.finalSummary,
              ),
            if (state.errorMessage != null)
              _ErrorBanner(
                message: state.errorMessage!,
                onRetry: () => ref
                    .read(interviewControllerProvider(widget.config).notifier)
                    .retry(),
              ),
            Expanded(
              child: state.status == InterviewViewStatus.starting
                  ? const Center(child: CircularProgressIndicator())
                  : isVoiceMode
                  ? Builder(
                      builder: (BuildContext context) {
                        final String? token = ref.watch(
                          authAccessTokenProvider,
                        );
                        final controllerNotifier = ref.read(
                          interviewControllerProvider(widget.config).notifier,
                        );
                        final String? audioUrl = currentQuestion == null
                            ? null
                            : controllerNotifier.getQuestionAudioUrl(
                                currentQuestion.id,
                              );

                        return _VoiceRoomPanel(
                          state: state,
                          currentQuestion: currentQuestion,
                          latestCandidateAnswer: latestCandidateAnswer,
                          audioUrl: audioUrl,
                          accessToken: token,
                        );
                      },
                    )
                  : Builder(
                      builder: (BuildContext context) {
                        final String? token = ref.watch(
                          authAccessTokenProvider,
                        );
                        final controllerNotifier = ref.read(
                          interviewControllerProvider(widget.config).notifier,
                        );

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          itemCount: state.messages.length + (isBusy ? 1 : 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (index < state.messages.length) {
                              final InterviewMessage msg =
                                  state.messages[index];
                              final String? audioUrl =
                                  (msg.author ==
                                          InterviewMessageAuthor.interviewer &&
                                      (msg.audioAvailable ||
                                          widget.config.responseStyle ==
                                              'voice'))
                                  ? controllerNotifier.getQuestionAudioUrl(
                                      msg.id,
                                    )
                                  : null;
                              return _ChatBubble(
                                message: msg,
                                audioUrl: audioUrl,
                                accessToken: token,
                              );
                            }
                            return const _TypingBubble();
                          },
                        );
                      },
                    ),
            ),
            if (state.latestEvaluation != null)
              _EvaluationStrip(evaluation: state.latestEvaluation!),
            if (state.status == InterviewViewStatus.completed)
              const _CompletedBanner()
            else
              _AnswerComposer(
                controller: _answerController,
                enabled: state.canSubmit,
                isBusy: isBusy,
                config: widget.config,
                onSubmit: _submitAnswer,
              ),
          ],
        ),
      ),
    );
  }

  InterviewMessage? _latestMessageByAuthor(
    List<InterviewMessage> messages,
    InterviewMessageAuthor author,
  ) {
    for (final InterviewMessage message in messages.reversed) {
      if (message.author == author) {
        return message;
      }
    }
    return null;
  }
}

class _InterviewHeader extends StatelessWidget {
  const _InterviewHeader({
    required this.status,
    required this.config,
    required this.currentQuestion,
    required this.finalSummary,
  });

  final InterviewViewStatus status;
  final InterviewLaunchConfig config;
  final InterviewMessage? currentQuestion;
  final InterviewFinalSummary? finalSummary;

  @override
  Widget build(BuildContext context) {
    final bool completed = status == InterviewViewStatus.completed;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.levelUpTeal.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.levelUpTeal, width: 2),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: AppColors.levelUpTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pewawancara AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${config.targetRole} - ${config.mode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  completed ? 'RINGKASAN SESI' : 'PERTANYAAN SAAT INI',
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withAlpha(160),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  completed && finalSummary != null
                      ? 'Skor akhir ${finalSummary!.overallScore.toStringAsFixed(1)} dari ${finalSummary!.answerCount} jawaban.'
                      : currentQuestion?.text ??
                            'Menyiapkan sesi interview AI...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textStrong,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _VoiceRoomPanel extends StatelessWidget {
  const _VoiceRoomPanel({
    required this.state,
    required this.currentQuestion,
    required this.latestCandidateAnswer,
    required this.audioUrl,
    required this.accessToken,
  });

  final InterviewState state;
  final InterviewMessage? currentQuestion;
  final InterviewMessage? latestCandidateAnswer;
  final String? audioUrl;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final bool isListening = state.isRecording;
    final bool isThinking = state.status == InterviewViewStatus.submitting;
    final String title = isListening
        ? 'Saya mendengarkan...'
        : isThinking
        ? 'Menyiapkan respons...'
        : 'Siap mendengarkan';
    final String subtitle = isListening
        ? 'Bicara dengan tenang, lalu tekan selesai.'
        : isThinking
        ? 'Pewawancara AI sedang menilai jawabanmu.'
        : 'Gunakan mic atau tetap ketik jawaban di bawah.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.warriorNavy,
            Color(0xFF123C76),
            AppColors.levelUpTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(45)),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Voice Interview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(185),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (audioUrl != null)
                _AudioPlayButton(
                  audioUrl: audioUrl!,
                  accessToken: accessToken,
                  color: Colors.white,
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 22),
          _VoiceVisualizerOrb(isActive: isListening || isThinking),
          const SizedBox(height: 24),
          Text(
            currentQuestion?.text ?? 'Menyiapkan pertanyaan interview...',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.38,
            ),
          ),
          if (latestCandidateAnswer != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(35)),
              ),
              child: Text(
                latestCandidateAnswer!.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

class _VoiceVisualizerOrb extends StatefulWidget {
  const _VoiceVisualizerOrb({required this.isActive});

  final bool isActive;

  @override
  State<_VoiceVisualizerOrb> createState() => _VoiceVisualizerOrbState();
}

class _VoiceVisualizerOrbState extends State<_VoiceVisualizerOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: const Size.square(150),
          painter: _VoiceOrbPainter(
            progress: _controller.value,
            isActive: widget.isActive,
          ),
        );
      },
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({required this.progress, required this.isActive});

  final double progress;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double baseRadius = size.shortestSide * 0.31;
    final Paint glowPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(isActive ? 55 : 32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, baseRadius * 1.45, glowPaint);

    final Paint corePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withAlpha(210),
          AppColors.fireGold.withAlpha(135),
          AppColors.levelUpTeal.withAlpha(90),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.2));
    canvas.drawCircle(center, baseRadius, corePaint);

    for (int ring = 0; ring < 4; ring += 1) {
      final double phase = progress + ring * 0.19;
      final double radius = baseRadius + ring * 8;
      final Path path = Path();
      for (int step = 0; step <= 96; step += 1) {
        final double angle = step / 96 * 6.283185307179586;
        final double wave =
            (isActive ? 7 : 3) *
            (0.65 + ring * 0.12) *
            (0.5 + 0.5 * _wave(angle * (ring + 2) + phase * 6.283185307179586));
        final double r = radius + wave;
        final Offset point = Offset(
          center.dx + r * _cos(angle),
          center.dy + r * _sin(angle),
        );
        if (step == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final Paint ringPaint = Paint()
        ..color = Color.lerp(
          AppColors.levelUpTeal,
          AppColors.fireGold,
          ring / 4,
        )!.withAlpha(isActive ? 175 - ring * 24 : 105 - ring * 16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawPath(path, ringPaint);
    }
  }

  double _wave(double value) {
    return _sin(value) * 0.65 + _sin(value * 1.7) * 0.35;
  }

  double _sin(double value) {
    return math.sin(value);
  }

  double _cos(double value) {
    return math.cos(value);
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.audioUrl, this.accessToken});

  final InterviewMessage message;
  final String? audioUrl;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.author == InterviewMessageAuthor.candidate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            const _AvatarIcon(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isUser ? AppColors.warriorNavy : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.warriorNavy.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  if (audioUrl != null && !isUser) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _AudioPlayButton(
                          audioUrl: audioUrl!,
                          accessToken: accessToken,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Dengarkan Audio',
                          style: TextStyle(
                            color: AppColors.levelUpTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...<Widget>[
            const SizedBox(width: 8),
            const _AvatarIcon(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _AudioPlayButton extends StatefulWidget {
  const _AudioPlayButton({
    required this.audioUrl,
    this.accessToken,
    this.color = AppColors.levelUpTeal,
  });

  final String audioUrl;
  final String? accessToken;
  final Color color;

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying =
              state.playing &&
              state.processingState != ProcessingState.completed;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      try {
        setState(() => _isLoading = true);
        final Map<String, String> headers = <String, String>{
          if (widget.accessToken != null && widget.accessToken!.isNotEmpty)
            'authorization': 'Bearer ${widget.accessToken}',
        };
        await _player.setUrl(widget.audioUrl, headers: headers);
        await _player.play();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal memutar audio: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.levelUpTeal,
        ),
      );
    }
    return InkWell(
      onTap: _togglePlay,
      borderRadius: BorderRadius.circular(999),
      child: Icon(
        _isPlaying
            ? Icons.pause_circle_filled_rounded
            : Icons.volume_up_rounded,
        color: widget.color,
        size: 22,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: <Widget>[
          _AvatarIcon(isUser: false),
          SizedBox(width: 8),
          _DotsBubble(),
        ],
      ),
    );
  }
}

class _DotsBubble extends StatelessWidget {
  const _DotsBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '...',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 24,
          height: 0.6,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _EvaluationStrip extends StatelessWidget {
  const _EvaluationStrip({required this.evaluation});

  final InterviewEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final String? firstImprovement = evaluation.improvements.isEmpty
        ? null
        : evaluation.improvements.first;
    final String note =
        evaluation.coachNote ??
        firstImprovement ??
        'Jawaban tersimpan. Lanjutkan ke pertanyaan berikutnya.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.levelUpTeal.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(70)),
      ),
      child: Text(
        'Coach note: $note',
        style: const TextStyle(
          color: AppColors.textStrong,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _AnswerComposer extends ConsumerStatefulWidget {
  const _AnswerComposer({
    required this.controller,
    required this.enabled,
    required this.isBusy,
    required this.config,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isBusy;
  final InterviewLaunchConfig config;
  final VoidCallback onSubmit;

  @override
  ConsumerState<_AnswerComposer> createState() => _AnswerComposerState();
}

class _AnswerComposerState extends ConsumerState<_AnswerComposer> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final String tempDir = Directory.systemTemp.path;
        final String path =
            '$tempDir/interview_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
        ref
            .read(interviewControllerProvider(widget.config).notifier)
            .setRecording(true);

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin mikrofon diperlukan untuk merekam suara.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memulai rekaman: $e')));
      }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    try {
      final String? path = await _audioRecorder.stop();
      if (mounted) {
        setState(() => _isRecording = false);
      }
      ref
          .read(interviewControllerProvider(widget.config).notifier)
          .setRecording(false);

      if (!cancel && path != null && path.isNotEmpty) {
        final File file = File(path);
        if (await file.exists()) {
          final List<int> bytes = await file.readAsBytes();
          if (mounted) {
            setState(() => _isTranscribing = true);
          }

          final String? transcript = await ref
              .read(interviewControllerProvider(widget.config).notifier)
              .transcribeAudio(bytes, 'recording.m4a');

          if (mounted) {
            setState(() => _isTranscribing = false);
            if (transcript != null && transcript.trim().isNotEmpty) {
              widget.controller.text = transcript;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = false;
        });
        ref
            .read(interviewControllerProvider(widget.config).notifier)
            .setRecording(false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memproses rekaman: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isVoice = widget.config.responseStyle == 'voice';
    final bool isBusy = widget.isBusy || _isTranscribing;

    if (_isRecording) {
      final String timeStr =
          '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(15),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: Colors.redAccent.withAlpha(60)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.fiber_manual_record,
              color: Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Merekam Suara... $timeStr',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Batal',
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              onPressed: () => _stopRecording(cancel: true),
            ),
            IconButton(
              tooltip: 'Selesai & Transkripsi',
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.levelUpTeal,
                size: 32,
              ),
              onPressed: () => _stopRecording(cancel: false),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          if (isVoice) ...<Widget>[
            IconButton(
              tooltip: 'Rekam Suara (Whisper STT)',
              icon: Icon(
                Icons.mic_rounded,
                color: widget.enabled && !isBusy
                    ? AppColors.levelUpTeal
                    : AppColors.textMuted,
              ),
              onPressed: widget.enabled && !isBusy ? _startRecording : null,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled && !_isTranscribing,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _isTranscribing
                    ? 'Memproses transkripsi suara...'
                    : widget.enabled
                    ? (isVoice
                          ? 'Bicara via mic atau ketik jawaban...'
                          : 'Ketik jawaban interview kamu...')
                    : 'Tunggu pewawancara AI...',
                filled: true,
                fillColor: AppColors.scholarCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (_isTranscribing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.levelUpTeal,
              ),
            )
          else
            FilledButton(
              onPressed: widget.enabled && !isBusy ? widget.onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warriorNavy,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
              ),
              child: const Icon(Icons.send_rounded),
            ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.levelUpTeal,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Sesi interview telah selesai.',
            style: TextStyle(
              color: AppColors.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsSheet extends ConsumerWidget {
  const _SessionsSheet({
    required this.currentSessionId,
    required this.config,
    required this.onOpenSession,
  });

  final String? currentSessionId;
  final InterviewLaunchConfig config;
  final ValueChanged<InterviewSessionSummaryRecord> onOpenSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InterviewSessionSummaryRecord>> sessionsAsync = ref
        .watch(interviewSessionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: sessionsAsync.when(
          data: (List<InterviewSessionSummaryRecord> sessions) {
            if (sessions.isEmpty) {
              return const Center(
                child: Text(
                  'Belum ada sesi interview tersimpan.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Riwayat Interview',
                  style: TextStyle(
                    color: AppColors.warriorNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sesi aktif baru: ${config.companyName}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final InterviewSessionSummaryRecord session =
                          sessions[index];
                      final bool isCurrent =
                          session.sessionId == currentSessionId;
                      final String title = _humanizeCompanyId(
                        session.companyId,
                      );
                      final String summaryText = session.finalSummary == null
                          ? 'Belum diselesaikan'
                          : 'Skor ${session.finalSummary!.overallScore.toStringAsFixed(1)}';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onOpenSession(session),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isCurrent
                                    ? AppColors.levelUpTeal
                                    : AppColors.warriorNavy.withAlpha(24),
                                width: isCurrent ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.warriorNavy.withAlpha(12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    session.status == 'completed'
                                        ? Icons.task_alt_rounded
                                        : Icons.history_rounded,
                                    color: session.status == 'completed'
                                        ? AppColors.levelUpTeal
                                        : AppColors.warriorNavy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textStrong,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.levelUpTeal
                                                    .withAlpha(18),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Aktif',
                                                style: TextStyle(
                                                  color: AppColors.levelUpTeal,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${session.targetRole} - ${session.mode}',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$summaryText  •  ${_sessionTimestamp(session.updatedAt)}',
                                        style: const TextStyle(
                                          color: AppColors.textStrong,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textMuted,
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
            );
          },
          error: (Object error, StackTrace stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Riwayat sesi belum bisa dimuat.',
                    style: TextStyle(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(interviewSessionsProvider),
                    child: const Text('Muat ulang'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _SessionDetailSheet extends ConsumerWidget {
  const _SessionDetailSheet({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InterviewSessionDetailRecord> detailAsync = ref.watch(
      interviewSessionDetailProvider(sessionId),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: detailAsync.when(
          data: (InterviewSessionDetailRecord detail) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _humanizeCompanyId(detail.companyId),
                  style: const TextStyle(
                    color: AppColors.warriorNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${detail.targetRole} - ${detail.mode}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.finalSummary != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.levelUpTeal.withAlpha(16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.levelUpTeal.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      'Skor akhir ${detail.finalSummary!.overallScore.toStringAsFixed(1)} dari ${detail.finalSummary!.answerCount} jawaban.',
                      style: const TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: detail.messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Transkrip sesi masih kosong.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: detail.messages.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final InterviewMessage message =
                                detail.messages[index];
                            return _SessionTranscriptTile(message: message);
                          },
                        ),
                ),
              ],
            );
          },
          error: (Object error, StackTrace stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Detail sesi belum bisa dimuat.',
                    style: TextStyle(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      interviewSessionDetailProvider(sessionId),
                    ),
                    child: const Text('Muat ulang'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _SessionTranscriptTile extends StatelessWidget {
  const _SessionTranscriptTile({required this.message});

  final InterviewMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isCandidate = message.author == InterviewMessageAuthor.candidate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCandidate
              ? AppColors.levelUpTeal.withAlpha(36)
              : AppColors.warriorNavy.withAlpha(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isCandidate
                    ? Icons.person_outline_rounded
                    : Icons.smart_toy_outlined,
                size: 18,
                color: isCandidate
                    ? AppColors.levelUpTeal
                    : AppColors.warriorNavy,
              ),
              const SizedBox(width: 8),
              Text(
                isCandidate ? 'Jawaban kamu' : 'Pewawancara AI',
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _messageTimestamp(message.createdAt),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.text,
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (message.evaluation?.coachNote != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.scholarCream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Coach note: ${message.evaluation!.coachNote!}',
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _humanizeCompanyId(String companyId) {
  if (companyId.trim().isEmpty) {
    return 'Interview Session';
  }
  return companyId
      .split(RegExp(r'[-_]'))
      .where((String part) => part.trim().isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _sessionTimestamp(DateTime time) {
  final DateTime now = DateTime.now();
  final Duration diff = now.difference(time);
  if (diff.inMinutes < 1) {
    return 'Baru saja';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m lalu';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}j lalu';
  }
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
}

String _messageTimestamp(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon({required this.isUser});

  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? AppColors.levelUpTeal.withAlpha(20)
            : Colors.grey.withAlpha(20),
        border: Border.all(
          color: isUser
              ? AppColors.levelUpTeal.withAlpha(100)
              : Colors.grey.withAlpha(100),
        ),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.smart_toy_outlined,
        size: 15,
        color: isUser ? AppColors.levelUpTeal : Colors.grey,
      ),
    );
  }
}
