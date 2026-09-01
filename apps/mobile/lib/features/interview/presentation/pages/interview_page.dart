import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';
import 'package:yudha_mobile/features/interview/presentation/audio/interview_audio_capture.dart';

class InterviewPage extends ConsumerStatefulWidget {
  const InterviewPage({required this.config, super.key});

  final InterviewLaunchConfig config;

  @override
  ConsumerState<InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends ConsumerState<InterviewPage>
    with WidgetsBindingObserver {
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interviewControllerProvider(widget.config).notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        widget.config.responseStyle == 'voice') {
      unawaited(
        ref
            .read(interviewControllerProvider(widget.config).notifier)
            .cancelLivePushToTalk(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final InterviewState state = ref.read(
      interviewControllerProvider(widget.config),
    );
    if (state.pendingAnswer != null && _answerController.text.isEmpty) {
      _answerController.text = state.pendingAnswer!.text;
      _answerController.selection = TextSelection.collapsed(
        offset: _answerController.text.length,
      );
    }
    _scrollToBottom();
  }

  Future<void> _completeSession() async {
    final bool shouldComplete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => const _InterviewConfirmationDialog(
            icon: Icons.task_alt_rounded,
            title: 'Selesaikan interview?',
            message:
                'Sesi akan ditutup dan hasil akhir disiapkan dari jawaban yang sudah terkirim.',
            cancelLabel: 'Kembali',
            confirmLabel: 'Selesaikan',
            confirmFill: Color(0xFFFFD8AA),
            confirmShadow: Color(0xFFF2A064),
            confirmForeground: Color(0xFFA9571B),
          ),
        ) ??
        false;
    if (!shouldComplete || !mounted) {
      return;
    }
    await ref
        .read(interviewControllerProvider(widget.config).notifier)
        .complete();
  }

  Future<void> _requestExit(InterviewState state) async {
    if (_allowPop) {
      return;
    }
    if (state.status == InterviewViewStatus.completed ||
        (state.sessionId == null && !state.isRecording)) {
      _popAfterAllowingExit();
      return;
    }
    final bool shouldLeave =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => _InterviewConfirmationDialog(
            icon: Icons.logout_rounded,
            title: 'Tinggalkan interview?',
            message: state.isRecording
                ? 'Rekaman yang sedang berlangsung akan dibatalkan. Sesi tetap tersimpan dan bisa dilanjutkan dari riwayat.'
                : 'Sesi tetap tersimpan dan bisa dilanjutkan dari riwayat interview.',
            cancelLabel: 'Tetap di sini',
            confirmLabel: 'Tinggalkan',
            confirmFill: const Color(0xFFFFE0DA),
            confirmShadow: const Color(0xFFECA092),
            confirmForeground: const Color(0xFFA63724),
          ),
        ) ??
        false;
    if (!shouldLeave || !mounted) {
      return;
    }
    _popAfterAllowingExit();
  }

  void _popAfterAllowingExit() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.pop();
      }
    });
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _SessionsSheet(
          currentSessionId: state.sessionId,
          config: widget.config,
          onOpenSession: (InterviewSessionSummaryRecord session) {
            if (session.status == 'active') {
              Navigator.of(context).pop();
              _continueSession(session, state.sessionId);
            } else {
              _showSessionDetail(session.sessionId);
            }
          },
        );
      },
    );
  }

  Future<void> _continueSession(
    InterviewSessionSummaryRecord session,
    String? currentSessionId,
  ) async {
    if (session.sessionId == currentSessionId) {
      return;
    }
    final bool shouldSwitch =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => const _InterviewConfirmationDialog(
            icon: Icons.switch_account_rounded,
            title: 'Lanjutkan sesi ini?',
            message:
                'Interview yang sedang terbuka tetap tersimpan di riwayat.',
            cancelLabel: 'Batal',
            confirmLabel: 'Lanjutkan',
            confirmFill: Color(0xFFDDEAFF),
            confirmShadow: Color(0xFF9CBCEB),
            confirmForeground: Color(0xFF0D49B5),
          ),
        ) ??
        false;
    if (!shouldSwitch || !mounted) {
      return;
    }
    context.pushReplacement(
      AppRoutes.interviewSession,
      extra: InterviewLaunchConfig(
        companyId: session.companyId,
        companyName: _humanizeCompanyId(session.companyId),
        targetRole: session.targetRole,
        mode: session.mode,
        language: session.language,
        responseStyle: session.responseStyle,
        resumeSessionId: session.sessionId,
      ),
    );
  }

  void _showSessionDetail(String sessionId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
      if (previous?.pendingAnswer != null && next.pendingAnswer == null) {
        _answerController.clear();
      }
    });

    final bool hasSubmittedAnswer =
        state.pendingAnswer == null &&
        state.messages.any(
          (InterviewMessage message) =>
              message.author == InterviewMessageAuthor.candidate,
        );

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_requestExit(state));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D49B5),
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: const Color(0xFF0D49B5),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _requestExit(state),
          ),
          title: Column(
            children: <Widget>[
              Text(
                'INTERVIEW AI',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0,
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
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: <Widget>[
            if (isVoiceMode && state.status != InterviewViewStatus.completed)
              IconButton(
                key: ValueKey<String>(
                  state.useTextFallback
                      ? 'live-interview-voice-fallback'
                      : 'live-interview-text-fallback',
                ),
                tooltip: state.useTextFallback
                    ? 'Beralih ke suara'
                    : 'Beralih ke teks',
                icon: Icon(
                  state.useTextFallback
                      ? Icons.mic_rounded
                      : Icons.chat_bubble_outline_rounded,
                ),
                onPressed: () {
                  final notifier = ref.read(
                    interviewControllerProvider(widget.config).notifier,
                  );
                  if (state.useTextFallback) {
                    notifier.switchLiveTextToVoice();
                  } else {
                    notifier.switchLiveVoiceToText();
                  }
                },
              ),
            IconButton(
              tooltip: 'Riwayat chat',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => _showHistory(state),
            ),
            if (state.status != InterviewViewStatus.completed &&
                (!isVoiceMode || state.useTextFallback))
              TextButton(
                onPressed: isBusy || !hasSubmittedAnswer
                    ? null
                    : _completeSession,
                child: const Text(
                  'Selesai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: DecoratedBox(
          key: const ValueKey<String>('interview-page-background'),
          decoration: BoxDecoration(
            color: state.status == InterviewViewStatus.completed
                ? AppColors.scholarCream
                : null,
            gradient: state.status == InterviewViewStatus.completed
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFF0D49B5),
                      Color(0xFF0875AE),
                      Color(0xFF06AAA9),
                    ],
                    stops: <double>[0, 0.48, 1],
                  ),
          ),
          child: SafeArea(
            child: state.status == InterviewViewStatus.completed
                ? _InterviewResultView(
                    config: widget.config,
                    summary: state.finalSummary,
                    latestEvaluation: state.latestEvaluation,
                    onStartNew: () => context.go(AppRoutes.interview),
                    onBackToPractice: () => context.go(AppRoutes.solo),
                  )
                : Column(
                    children: <Widget>[
                      if (!isVoiceMode || state.useTextFallback)
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
                              .read(
                                interviewControllerProvider(
                                  widget.config,
                                ).notifier,
                              )
                              .retry(),
                        ),
                      Expanded(
                        child: state.status == InterviewViewStatus.starting
                            ? const Center(child: CircularProgressIndicator())
                            : isVoiceMode && !state.useTextFallback
                            ? Builder(
                                builder: (BuildContext context) {
                                  return _VoiceRoomPanel(
                                    state: state,
                                    currentQuestion: currentQuestion,
                                    latestCandidateAnswer:
                                        latestCandidateAnswer,
                                    onPushToTalkStart: () => ref
                                        .read(
                                          interviewControllerProvider(
                                            widget.config,
                                          ).notifier,
                                        )
                                        .beginLivePushToTalk(),
                                    onPushToTalkEnd: () => ref
                                        .read(
                                          interviewControllerProvider(
                                            widget.config,
                                          ).notifier,
                                        )
                                        .endLivePushToTalk(),
                                    onPushToTalkCancel: () => ref
                                        .read(
                                          interviewControllerProvider(
                                            widget.config,
                                          ).notifier,
                                        )
                                        .cancelLivePushToTalk(),
                                    onReconnect: () => ref
                                        .read(
                                          interviewControllerProvider(
                                            widget.config,
                                          ).notifier,
                                        )
                                        .reconnectLiveVoice(),
                                    onTextFallback: () => ref
                                        .read(
                                          interviewControllerProvider(
                                            widget.config,
                                          ).notifier,
                                        )
                                        .switchLiveVoiceToText(),
                                    onEndCall: () => hasSubmittedAnswer
                                        ? _completeSession()
                                        : _requestExit(state),
                                  );
                                },
                              )
                            : Builder(
                                builder: (BuildContext context) {
                                  final String? token = ref.watch(
                                    authAccessTokenProvider,
                                  );
                                  final controllerNotifier = ref.read(
                                    interviewControllerProvider(
                                      widget.config,
                                    ).notifier,
                                  );

                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      20,
                                    ),
                                    itemCount:
                                        state.messages.length +
                                        (isBusy ? 1 : 0),
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          if (index < state.messages.length) {
                                            final InterviewMessage msg =
                                                state.messages[index];
                                            final String? audioUrl =
                                                (msg.author ==
                                                        InterviewMessageAuthor
                                                            .interviewer &&
                                                    (msg.audioAvailable ||
                                                        widget
                                                                .config
                                                                .responseStyle ==
                                                            'voice'))
                                                ? controllerNotifier
                                                      .getQuestionAudioUrl(
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
                      if (!isVoiceMode || state.useTextFallback)
                        _AnswerComposer(
                          controller: _answerController,
                          enabled: state.canSubmit,
                          isBusy: isBusy,
                          config: widget.config,
                          allowVoiceRecording: !state.useTextFallback,
                          onSubmit: _submitAnswer,
                        ),
                    ],
                  ),
          ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(65), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF002966).withAlpha(60),
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.levelUpTeal, AppColors.warriorNavy],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(90), width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Pewawancara AI',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.growthLime.withAlpha(45),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.growthLime.withAlpha(90),
                        ),
                      ),
                      child: Text(
                        'ONLINE',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.growthLime,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${config.targetRole} • ${_humanizeInterviewMode(config.mode)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withAlpha(200),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
    required this.onPushToTalkStart,
    required this.onPushToTalkEnd,
    required this.onPushToTalkCancel,
    required this.onReconnect,
    required this.onTextFallback,
    required this.onEndCall,
  });

  final InterviewState state;
  final InterviewMessage? currentQuestion;
  final InterviewMessage? latestCandidateAnswer;
  final VoidCallback onPushToTalkStart;
  final VoidCallback onPushToTalkEnd;
  final VoidCallback onPushToTalkCancel;
  final VoidCallback onReconnect;
  final VoidCallback onTextFallback;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    final _LiveVoiceCopy copy = _liveVoiceCopy(state.livePhase);
    final bool isActive = switch (state.livePhase) {
      LiveInterviewPhase.connecting ||
      LiveInterviewPhase.interviewerSpeaking ||
      LiveInterviewPhase.readyToAnswer ||
      LiveInterviewPhase.candidateSpeaking ||
      LiveInterviewPhase.transcribing ||
      LiveInterviewPhase.evaluating ||
      LiveInterviewPhase.reconnecting => true,
      _ => false,
    };

    return Container(
      key: const ValueKey<String>('interview-voice-stage'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: <Widget>[
          if (state.liveErrorMessage != null) ...<Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1A1A).withAlpha(220),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFB4A9).withAlpha(120),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFFE0C2),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.liveErrorMessage!,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFFFE0C2),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            key: const ValueKey<String>('interview-voice-mode-card'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(65), width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF002966).withAlpha(60),
                  blurRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.levelUpTeal,
                        AppColors.warriorNavy,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withAlpha(90),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              'Interview Suara',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.growthLime.withAlpha(45),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.growthLime.withAlpha(90),
                              ),
                            ),
                            child: Text(
                              'LIVE AI',
                              style: GoogleFonts.jetBrainsMono(
                                color: AppColors.growthLime,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        copy.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withAlpha(200),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.livePhase == LiveInterviewPhase.degraded
                        ? Icons.wifi_off_rounded
                        : Icons.graphic_eq_rounded,
                    color: state.livePhase == LiveInterviewPhase.degraded
                        ? const Color(0xFFFFB4A9)
                        : AppColors.fireGold,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _VoiceVisualizerOrb(isActive: isActive),
          const Spacer(),
          Container(
            key: const ValueKey<String>('interview-question-surface'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 85, maxHeight: 130),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withAlpha(60), width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF002966).withAlpha(50),
                  blurRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _ScrollableInterviewQuestion(
              text:
                  currentQuestion?.text ?? 'Menyiapkan pertanyaan interview...',
            ),
          ),
          if (latestCandidateAnswer != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.warriorNavy.withAlpha(110),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.levelUpTeal.withAlpha(80),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF001944).withAlpha(70),
                    blurRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.fireGold,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latestCandidateAnswer!.text,
                      textAlign: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withAlpha(235),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _LiveCallControls(
            phase: state.livePhase,
            recordingDuration: state.liveRecordingDuration,
            showReconnect: state.livePhase == LiveInterviewPhase.degraded,
            onPushToTalkStart: onPushToTalkStart,
            onPushToTalkEnd: onPushToTalkEnd,
            onPushToTalkCancel: onPushToTalkCancel,
            onReconnect: onReconnect,
            onTextFallback: onTextFallback,
            onEndCall: onEndCall,
          ),
        ],
      ),
    );
  }
}

class _LiveVoiceCopy {
  const _LiveVoiceCopy(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

_LiveVoiceCopy _liveVoiceCopy(LiveInterviewPhase phase) {
  return switch (phase) {
    LiveInterviewPhase.connecting => const _LiveVoiceCopy(
      'Menghubungkan panggilan...',
      'Menyiapkan koneksi audio yang aman.',
    ),
    LiveInterviewPhase.interviewerSpeaking => const _LiveVoiceCopy(
      'Pewawancara sedang berbicara',
      'Dengarkan pertanyaan, lalu jawab setelah audio selesai.',
    ),
    LiveInterviewPhase.readyToAnswer => const _LiveVoiceCopy(
      'Siap mendengar jawabanmu',
      'Tekan dan tahan tombol mikrofon untuk menjawab.',
    ),
    LiveInterviewPhase.candidateSpeaking => const _LiveVoiceCopy(
      'Jawaban sedang direkam',
      'Lepaskan tombol untuk mengirim jawaban.',
    ),
    LiveInterviewPhase.transcribing => const _LiveVoiceCopy(
      'Menyiapkan transkrip...',
      'Jawaban akhir sedang diubah menjadi teks.',
    ),
    LiveInterviewPhase.evaluating => const _LiveVoiceCopy(
      'Menilai jawaban...',
      'Pewawancara sedang menyiapkan pertanyaan berikutnya.',
    ),
    LiveInterviewPhase.reconnecting => const _LiveVoiceCopy(
      'Menyambungkan kembali...',
      'Jawaban yang belum selesai tetap dijaga di perangkat.',
    ),
    LiveInterviewPhase.degraded => const _LiveVoiceCopy(
      'Mode Suara',
      'Sambungkan lagi atau lanjutkan sesi lewat teks.',
    ),
    LiveInterviewPhase.completed => const _LiveVoiceCopy(
      'Interview selesai',
      'Hasil akhir sedang disiapkan.',
    ),
    LiveInterviewPhase.disconnected => const _LiveVoiceCopy(
      'Menyiapkan interview suara',
      'Panggilan akan dimulai otomatis.',
    ),
  };
}

class _LiveCallControls extends StatelessWidget {
  const _LiveCallControls({
    required this.phase,
    required this.recordingDuration,
    required this.showReconnect,
    required this.onPushToTalkStart,
    required this.onPushToTalkEnd,
    required this.onPushToTalkCancel,
    required this.onReconnect,
    required this.onTextFallback,
    required this.onEndCall,
  });

  final LiveInterviewPhase phase;
  final Duration recordingDuration;
  final bool showReconnect;
  final VoidCallback onPushToTalkStart;
  final VoidCallback onPushToTalkEnd;
  final VoidCallback onPushToTalkCancel;
  final VoidCallback onReconnect;
  final VoidCallback onTextFallback;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _LiveCallButton(
          key: const ValueKey<String>('live-interview-reconnect'),
          icon: Icons.refresh_rounded,
          label: 'Sambung',
          background: AppColors.levelUpTeal,
          shadowColor: const Color(0xFF006575),
          enabled: showReconnect,
          onPressed: showReconnect ? onReconnect : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PushToTalkButton(
            canStart: phase == LiveInterviewPhase.readyToAnswer,
            isSpeaking: phase == LiveInterviewPhase.candidateSpeaking,
            recordingDuration: recordingDuration,
            onStart: onPushToTalkStart,
            onEnd: onPushToTalkEnd,
            onCancel: onPushToTalkCancel,
          ),
        ),
        const SizedBox(width: 10),
        _LiveCallButton(
          key: const ValueKey<String>('live-interview-end-call'),
          icon: Icons.call_end_rounded,
          label: 'Akhiri',
          background: const Color(0xFFE94D4D),
          shadowColor: const Color(0xFFB52A2A),
          onPressed: onEndCall,
        ),
      ],
    );
  }
}

class _PushToTalkButton extends StatefulWidget {
  const _PushToTalkButton({
    required this.canStart,
    required this.isSpeaking,
    required this.recordingDuration,
    required this.onStart,
    required this.onEnd,
    required this.onCancel,
  });

  final bool canStart;
  final bool isSpeaking;
  final Duration recordingDuration;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  State<_PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<_PushToTalkButton> {
  int? _pointer;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _PushToTalkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canStart && !widget.isSpeaking && _pointer != null) {
      _pointer = null;
      _pressed = false;
    }
  }

  void _handleDown(PointerDownEvent event) {
    if (!widget.canStart || _pointer != null) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _pressed = true;
    });
    widget.onStart();
  }

  void _handleUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    setState(() {
      _pointer = null;
      _pressed = false;
    });
    widget.onEnd();
  }

  void _handleCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    setState(() {
      _pointer = null;
      _pressed = false;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final bool recording = _pressed || widget.isSpeaking;
    final bool enabled = widget.canStart || widget.isSpeaking;
    final String label = recording
        ? 'Lepaskan untuk mengirim'
        : 'Tekan dan tahan untuk menjawab';
    final String elapsed = _formatLiveRecordingDuration(
      widget.recordingDuration,
    );

    // Claymorphism colors adapted from Home Lobby Clay Buttons
    final Color topFaceColor = recording
        ? const Color(0xFFFF5252)
        : enabled
        ? const Color(0xFFFFD8A6)
        : Colors.white.withAlpha(28);
    final Color shadowBaseColor = recording
        ? const Color(0xFFC62828)
        : enabled
        ? const Color(0xFFF2A45E)
        : const Color(0xFF002966).withAlpha(50);
    final Color contentColor = recording
        ? Colors.white
        : enabled
        ? const Color(0xFF8A4A12)
        : Colors.white60;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: recording
          ? 'Lepaskan jari untuk mengirim jawaban.'
          : 'Tahan tombol sambil berbicara.',
      child: Listener(
        key: const ValueKey<String>('live-interview-push-to-talk'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handleDown,
        onPointerUp: _handleUp,
        onPointerCancel: _handleCancel,
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Bottom 3D Clay Shadow Layer
              Positioned.fill(
                top: recording ? 2 : 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shadowBaseColor,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: recording
                        ? <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFFFF5252).withAlpha(120),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                ),
              ),
              // Top Face Interactive Container
              Positioned.fill(
                bottom: recording ? 2 : 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: topFaceColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: recording
                          ? const Color(0xFFFFCDD2)
                          : enabled
                          ? Colors.white.withAlpha(210)
                          : Colors.white.withAlpha(45),
                      width: 1.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: recording
                              ? Colors.white.withAlpha(45)
                              : enabled
                              ? const Color(0xFFF2A45E).withAlpha(60)
                              : Colors.white.withAlpha(15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          recording
                              ? Icons.mic_rounded
                              : Icons.touch_app_rounded,
                          color: contentColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                color: contentColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (recording)
                              Text(
                                '$elapsed / 01:30',
                                key: const ValueKey<String>(
                                  'live-interview-recording-duration',
                                ),
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white.withAlpha(235),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatLiveRecordingDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds.clamp(0, 90);
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _LiveCallButton extends StatelessWidget {
  const _LiveCallButton({
    required super.key,
    required this.icon,
    required this.label,
    required this.background,
    this.shadowColor,
    this.enabled = true,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color? shadowColor;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color shadow = shadowColor ?? const Color(0xFF002966);
    final Color effectiveBg = enabled ? background : Colors.white.withAlpha(20);
    final Color effectiveShadow = enabled
        ? shadow
        : const Color(0xFF001944).withAlpha(40);
    final Color iconColor = enabled ? Colors.white : Colors.white.withAlpha(80);
    final Color textColor = enabled
        ? Colors.white.withAlpha(230)
        : Colors.white.withAlpha(80);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                top: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: effectiveShadow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned.fill(
                bottom: 4,
                child: Material(
                  color: effectiveBg,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Tooltip(
                    message: label,
                    child: InkWell(
                      onTap: enabled ? onPressed : null,
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ScrollableInterviewQuestion extends StatefulWidget {
  const _ScrollableInterviewQuestion({required this.text});

  final String text;

  @override
  State<_ScrollableInterviewQuestion> createState() =>
      _ScrollableInterviewQuestionState();
}

class _ScrollableInterviewQuestionState
    extends State<_ScrollableInterviewQuestion> {
  final ScrollController _scrollController = ScrollController();
  bool _showTopFade = false;
  bool _showBottomFade = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant _ScrollableInterviewQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.jumpTo(0);
        _updateFades();
      });
    }
  }

  void _updateFades() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    final bool showTop = position.pixels > 1;
    final bool showBottom =
        position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 1;
    if (showTop != _showTopFade || showBottom != _showBottomFade) {
      setState(() {
        _showTopFade = showTop;
        _showBottomFade = showBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateFades)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _showTopFade ? Colors.transparent : Colors.white,
          Colors.white,
          Colors.white,
          _showBottomFade ? Colors.transparent : Colors.white,
        ],
        stops: const <double>[0, 0.12, 0.88, 1],
      ).createShader(bounds),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
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
          key: const ValueKey<String>('interview-voice-orb'),
          size: const Size.square(230),
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
    final double baseRadius = size.shortestSide * 0.28;
    final double intensity = isActive ? 1.0 : 0.45;

    // 1. Ambient Dynamic Glows
    final Path ambientGlowPath = _generateFluidBlobPath(
      center: center,
      baseRadius:
          baseRadius *
          (1.35 + (isActive ? 0.12 : 0.05) * math.sin(progress * 2 * math.pi)),
      phase: progress,
      distortion: isActive ? 0.18 : 0.09,
      frequencyMultiplier: 1.0,
      rotationOffset: progress * math.pi,
    );
    final Paint glowPaintTeal = Paint()
      ..color = AppColors.levelUpTeal.withAlpha((50 * intensity).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawPath(ambientGlowPath, glowPaintTeal);

    final Paint glowPaintGold = Paint()
      ..color = AppColors.fireGold.withAlpha((40 * intensity).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, baseRadius * 1.15, glowPaintGold);

    // 2. Main Fluid Organic Core Body
    final Path coreBlobPath = _generateFluidBlobPath(
      center: center,
      baseRadius: baseRadius,
      phase: progress,
      distortion: isActive ? 0.13 : 0.06,
      frequencyMultiplier: 1.2,
      rotationOffset: -progress * 2 * math.pi,
    );

    // 3D Spherical Radial Depth Gradient
    final Offset lightSource = Offset(
      center.dx - baseRadius * 0.28,
      center.dy - baseRadius * 0.28,
    );
    final Paint corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 1.1,
        colors: <Color>[
          Colors.white.withAlpha(245),
          AppColors.scholarCream.withAlpha(235),
          AppColors.fireGold.withAlpha(210),
          AppColors.levelUpTeal.withAlpha(200),
          const Color(0xFF00387A).withAlpha(220),
        ],
        stops: const <double>[0.0, 0.22, 0.52, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.3));
    canvas.drawPath(coreBlobPath, corePaint);

    // 3. Secondary Inner Plasma Swirl (Layered for visual richness)
    final Path innerSwirlPath = _generateFluidBlobPath(
      center: center,
      baseRadius: baseRadius * 0.72,
      phase: progress * 1.4,
      distortion: isActive ? 0.16 : 0.08,
      frequencyMultiplier: 1.8,
      rotationOffset: progress * 2.5 * math.pi,
    );
    final Paint innerSwirlPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.2),
        radius: 0.9,
        colors: <Color>[
          AppColors.growthLime.withAlpha((140 * intensity).round()),
          AppColors.fireGold.withAlpha((100 * intensity).round()),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawPath(innerSwirlPath, innerSwirlPaint);

    // 4. Fluid Harmonic Wave Ribbons
    final int ringCount = isActive ? 4 : 3;
    for (int ring = 0; ring < ringCount; ring += 1) {
      final double ringPhase = progress + (ring * 0.22);
      final double ringBaseRadius =
          baseRadius + (ring + 1) * (isActive ? 7.5 : 5.5);
      final double ringDistortion =
          (isActive ? 0.12 : 0.06) * (1.0 + ring * 0.25);

      final Path ringPath = _generateFluidBlobPath(
        center: center,
        baseRadius: ringBaseRadius,
        phase: ringPhase,
        distortion: ringDistortion,
        frequencyMultiplier: 1.0 + (ring * 0.4),
        rotationOffset: (ring.isEven ? 1 : -1) * progress * 2 * math.pi,
      );

      final double colorT = ring / (ringCount > 1 ? (ringCount - 1) : 1);
      final Color strokeColor = Color.lerp(
        AppColors.levelUpTeal,
        AppColors.fireGold,
        colorT,
      )!;

      final Paint ringPaint = Paint()
        ..color = strokeColor.withAlpha(
          (isActive ? (180 - ring * 28) : (100 - ring * 20)).clamp(20, 255),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? (2.4 - ring * 0.3) : 1.6;
      canvas.drawPath(ringPath, ringPaint);
    }

    // 5. Specular Organic Glaze (Top-left Highlight Sheen)
    final Path specularPath = Path();
    final double specRadius = baseRadius * 0.55;
    specularPath.addOval(
      Rect.fromCenter(
        center: Offset(lightSource.dx + 4, lightSource.dy + 4),
        width: specRadius * 1.1,
        height: specRadius * 0.65,
      ),
    );
    final Paint specPaint = Paint()
      ..color = Colors.white.withAlpha(isActive ? 110 : 60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(specularPath, specPaint);
  }

  Path _generateFluidBlobPath({
    required Offset center,
    required double baseRadius,
    required double phase,
    required double distortion,
    required double frequencyMultiplier,
    required double rotationOffset,
  }) {
    final Path path = Path();
    const int steps = 96;
    for (int i = 0; i <= steps; i += 1) {
      final double angle = (i / steps) * 2 * math.pi;
      final double sampleAngle = angle + rotationOffset;

      // Harmonic fluid sinusoidal deformation
      final double wave1 =
          math.sin(
            sampleAngle * 2 * frequencyMultiplier + phase * 2 * math.pi,
          ) *
          0.45;
      final double wave2 =
          math.cos(
            sampleAngle * 3 * frequencyMultiplier - phase * 2 * math.pi * 1.2,
          ) *
          0.35;
      final double wave3 =
          math.sin(
            sampleAngle * 5 * frequencyMultiplier + phase * 2 * math.pi * 0.8,
          ) *
          0.20;

      final double deform = (wave1 + wave2 + wave3) * distortion;
      final double r = baseRadius * (1.0 + deform);

      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
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

  Future<void> _showFeedback(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _EvaluationDetailsSheet(evaluation: message.evaluation!),
    );
  }

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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF0D49B5) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 22),
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.white.withAlpha(50)
                      : Colors.white.withAlpha(200),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: isUser
                        ? const Color(0xFF00225E).withAlpha(120)
                        : const Color(0xFF002966).withAlpha(45),
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.text,
                    style: GoogleFonts.dmSans(
                      color: isUser ? Colors.white : AppColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  if (isUser && message.evaluation != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withAlpha(60),
                          width: 1,
                        ),
                      ),
                      child: TextButton.icon(
                        onPressed: () => _showFeedback(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.fireGold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.insights_outlined,
                          size: 15,
                          color: AppColors.fireGold,
                        ),
                        label: Text(
                          'Lihat Umpan Balik',
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (audioUrl != null && !isUser) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scholarCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.levelUpTeal.withAlpha(60),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _AudioPlayButton(
                            audioUrl: audioUrl!,
                            accessToken: accessToken,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dengarkan Audio',
                            style: GoogleFonts.fredoka(
                              color: AppColors.levelUpTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
  const _AudioPlayButton({required this.audioUrl, this.accessToken});

  final String audioUrl;
  final String? accessToken;

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  static _AudioPlayButtonState? _activePlayer;

  late AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPrepared = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
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
  void didUpdateWidget(covariant _AudioPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl == widget.audioUrl &&
        oldWidget.accessToken == widget.accessToken) {
      return;
    }
    unawaited(_player.stop());
    _isPrepared = false;
    _hasError = false;
  }

  @override
  void dispose() {
    if (identical(_activePlayer, this)) {
      _activePlayer = null;
    }
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isLoading) {
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      try {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
        final _AudioPlayButtonState? activePlayer = _activePlayer;
        if (activePlayer != null && !identical(activePlayer, this)) {
          await activePlayer._player.pause();
        }
        _activePlayer = this;
        if (!_isPrepared) {
          final Map<String, String> headers = <String, String>{
            if (widget.accessToken != null && widget.accessToken!.isNotEmpty)
              'authorization': 'Bearer ${widget.accessToken}',
          };
          await _player.setUrl(widget.audioUrl, headers: headers);
          _isPrepared = true;
        } else if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      } catch (_) {
        if (mounted) {
          setState(() => _hasError = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Audio pertanyaan belum dapat diputar. Kamu tetap bisa membaca pertanyaannya.',
              ),
            ),
          );
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
    return Tooltip(
      message: _hasError ? 'Coba putar lagi' : 'Dengarkan pertanyaan',
      child: InkWell(
        onTap: _togglePlay,
        borderRadius: BorderRadius.circular(999),
        child: Icon(
          _isPlaying
              ? Icons.pause_circle_filled_rounded
              : _hasError
              ? Icons.replay_rounded
              : Icons.volume_up_rounded,
          color: AppColors.levelUpTeal,
          size: 22,
        ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(210), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF002966).withAlpha(45),
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '...',
        style: GoogleFonts.fredoka(
          color: AppColors.levelUpTeal,
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

  Future<void> _showDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _EvaluationDetailsSheet(evaluation: evaluation),
    );
  }

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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(220), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF002966).withAlpha(50),
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.scholarCream,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.levelUpTeal.withAlpha(80),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.levelUpTeal.withAlpha(40),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    evaluation.overallScore.toStringAsFixed(0),
                    style: GoogleFonts.fredoka(
                      color: AppColors.warriorNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Umpan Balik Jawaban',
                            style: GoogleFonts.fredoka(
                              color: AppColors.warriorNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.levelUpTeal.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AI Coach',
                              style: GoogleFonts.fredoka(
                                color: AppColors.levelUpTeal,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: AppColors.textStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.scholarCream,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.warriorNavy,
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

class _EvaluationDetailsSheet extends StatelessWidget {
  const _EvaluationDetailsSheet({required this.evaluation});

  final InterviewEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final String? note = evaluation.coachNote?.trim();
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          widthFactor: 1,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warriorNavy.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.scholarCream,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.levelUpTeal.withAlpha(80),
                            width: 1.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.levelUpTeal.withAlpha(40),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          evaluation.overallScore.toStringAsFixed(0),
                          style: GoogleFonts.fredoka(
                            color: AppColors.warriorNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Umpan Balik Jawaban',
                              style: GoogleFonts.fredoka(
                                color: AppColors.warriorNavy,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Evaluasi performa & rekomendasi',
                              style: GoogleFonts.dmSans(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.warriorNavy,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.warriorNavy.withAlpha(20)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (note != null && note.isNotEmpty) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.scholarCream,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.fireGold.withAlpha(80),
                                width: 1.2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.fireGold.withAlpha(35),
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.fireGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.textStrong,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (evaluation.dimensions.hasScores) ...<Widget>[
                          _DimensionGrid(dimensions: evaluation.dimensions),
                          const SizedBox(height: 22),
                        ],
                        if (evaluation.strengths.isNotEmpty)
                          _FeedbackList(
                            title: 'Yang Sudah Kuat',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.levelUpTeal,
                            items: evaluation.strengths,
                          ),
                        if (evaluation.improvements.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          _FeedbackList(
                            title: 'Fokus Perbaikan',
                            icon: Icons.trending_up_rounded,
                            color: AppColors.fireGold,
                            items: evaluation.improvements,
                          ),
                        ],
                        if ((evaluation.suggestedRewrite ?? '')
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          _SuggestedRewrite(
                            text: evaluation.suggestedRewrite!.trim(),
                            title: 'Contoh Jawaban yang Lebih Kuat',
                          ),
                        ],
                      ],
                    ),
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

class _DimensionGrid extends StatelessWidget {
  const _DimensionGrid({required this.dimensions});

  final InterviewDimensions dimensions;

  @override
  Widget build(BuildContext context) {
    final List<_DimensionScore> scores = <_DimensionScore>[
      _DimensionScore('Relevansi', dimensions.relevance),
      _DimensionScore('Kejelasan', dimensions.clarity),
      _DimensionScore('Struktur', dimensions.structure),
      _DimensionScore('Keyakinan', dimensions.confidence),
      _DimensionScore('Dampak', dimensions.impact),
      _DimensionScore('Keaslian', dimensions.authenticity),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: scores
              .map(
                (_DimensionScore score) => SizedBox(
                  width: itemWidth,
                  child: _DimensionTile(score: score),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _DimensionScore {
  const _DimensionScore(this.label, this.value);

  final String label;
  final double value;
}

class _DimensionTile extends StatelessWidget {
  const _DimensionTile({required this.score});

  final _DimensionScore score;

  @override
  Widget build(BuildContext context) {
    final double normalized = (score.value / 100).clamp(0, 1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scholarCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(200), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF002966).withAlpha(20),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  score.label,
                  style: GoogleFonts.fredoka(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                score.value.toStringAsFixed(0),
                style: GoogleFonts.fredoka(
                  color: AppColors.warriorNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 6,
              color: score.value >= 75
                  ? AppColors.levelUpTeal
                  : AppColors.fireGold,
              backgroundColor: AppColors.warriorNavy.withAlpha(16),
            ),
          ),
        ],
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
    this.allowVoiceRecording = true,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isBusy;
  final InterviewLaunchConfig config;
  final VoidCallback onSubmit;
  final bool allowVoiceRecording;

  @override
  ConsumerState<_AnswerComposer> createState() => _AnswerComposerState();
}

class _AnswerComposerState extends ConsumerState<_AnswerComposer>
    with WidgetsBindingObserver {
  static const int _maxRecordingSeconds = 90;
  static const int _maxRecordingBytes = 10 * 1024 * 1024;

  final InterviewAudioCapture _audioCapture = createInterviewAudioCapture();
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isStopping = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  List<int>? _pendingAudioBytes;
  String _pendingAudioFilename = 'recording.m4a';
  String? _voiceMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    unawaited(_audioCapture.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRecording && state != AppLifecycleState.resumed) {
      unawaited(_stopRecording(cancel: true));
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isStopping || _isTranscribing) {
      return;
    }
    try {
      if (await _audioCapture.hasPermission()) {
        await _audioCapture.start();

        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _pendingAudioBytes = null;
          _voiceMessage = null;
        });
        ref
            .read(interviewControllerProvider(widget.config).notifier)
            .setRecording(true);

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordSeconds++);
            if (_recordSeconds >= _maxRecordingSeconds) {
              timer.cancel();
              unawaited(_stopRecording());
            }
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _voiceMessage =
                'Aktifkan izin mikrofon dari pengaturan perangkat, atau ketik jawaban.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceMessage =
              'Rekaman belum dapat dimulai. Kamu tetap bisa mengetik jawaban.';
        });
      }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (_isStopping) {
      return;
    }
    _recordTimer?.cancel();
    setState(() => _isStopping = true);
    try {
      final CapturedInterviewAudio? recording = await _audioCapture.stop(
        cancel: cancel,
      );
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
      ref
          .read(interviewControllerProvider(widget.config).notifier)
          .setRecording(false);

      if (!cancel && recording != null) {
        if (recording.bytes.length > _maxRecordingBytes) {
          if (mounted) {
            setState(() {
              _pendingAudioBytes = null;
              _voiceMessage =
                  'Rekaman terlalu besar. Coba jawaban yang lebih singkat.';
            });
          }
        } else {
          _pendingAudioBytes = recording.bytes;
          _pendingAudioFilename = recording.filename;
        }
      }
      if (!cancel && _pendingAudioBytes != null) {
        await _transcribePendingAudio();
      } else if (mounted && cancel) {
        setState(() {
          _pendingAudioBytes = null;
          _voiceMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = false;
          _voiceMessage =
              'Rekaman belum dapat diproses. Coba lagi atau ketik jawaban.';
        });
        ref
            .read(interviewControllerProvider(widget.config).notifier)
            .setRecording(false);
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _transcribePendingAudio() async {
    final List<int>? bytes = _pendingAudioBytes;
    if (bytes == null || bytes.isEmpty || _isTranscribing) {
      return;
    }
    setState(() {
      _isTranscribing = true;
      _voiceMessage = 'Sedang menyiapkan transkrip jawaban...';
    });
    final String? transcript = await ref
        .read(interviewControllerProvider(widget.config).notifier)
        .transcribeAudio(bytes, _pendingAudioFilename);
    if (!mounted) {
      return;
    }
    setState(() {
      _isTranscribing = false;
      if (transcript != null && transcript.trim().isNotEmpty) {
        widget.controller.text = transcript.trim();
        _pendingAudioBytes = null;
        _voiceMessage = 'Transkrip siap. Periksa sebelum mengirim.';
      } else {
        final InterviewState state = ref.read(
          interviewControllerProvider(widget.config),
        );
        _voiceMessage =
            state.transcriptionErrorMessage ??
            'Suara belum berhasil diubah menjadi teks. Coba transkripsi lagi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isVoice =
        widget.config.responseStyle == 'voice' && widget.allowVoiceRecording;
    final bool isBusy = widget.isBusy || _isTranscribing;

    if (_isRecording) {
      final String timeStr =
          '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}';
      return Container(
        key: const ValueKey<String>('interview-recording-composer'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: const Color(0xFFFF8A80).withAlpha(120),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFD32F2F).withAlpha(50),
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fiber_manual_record,
                color: Color(0xFFD32F2F),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Merekam Suara... $timeStr',
              style: GoogleFonts.fredoka(
                color: const Color(0xFFD32F2F),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Batal',
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              onPressed: _isStopping
                  ? null
                  : () => _stopRecording(cancel: true),
            ),
            IconButton(
              tooltip: 'Selesai & Transkripsi',
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.levelUpTeal,
                size: 32,
              ),
              onPressed: _isStopping
                  ? null
                  : () => _stopRecording(cancel: false),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey<String>('interview-floating-composer'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(230), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF002966).withAlpha(55),
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isVoice && _voiceMessage != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: <Widget>[
                  Icon(
                    _pendingAudioBytes == null
                        ? Icons.info_outline_rounded
                        : Icons.refresh_rounded,
                    size: 17,
                    color: AppColors.levelUpTeal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _voiceMessage!,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_pendingAudioBytes != null && !_isTranscribing)
                    TextButton(
                      onPressed: _transcribePendingAudio,
                      child: Text(
                        'Coba lagi',
                        style: GoogleFonts.fredoka(
                          color: AppColors.levelUpTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: <Widget>[
              if (isVoice) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: widget.enabled && !isBusy
                        ? AppColors.scholarCream
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Rekam jawaban',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: Icon(
                      Icons.mic_rounded,
                      size: 20,
                      color: widget.enabled && !isBusy
                          ? AppColors.levelUpTeal
                          : AppColors.textMuted,
                    ),
                    onPressed: widget.enabled && !isBusy
                        ? _startRecording
                        : null,
                  ),
                ),
              ],
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('interview-answer-field'),
                  controller: widget.controller,
                  enabled: widget.enabled && !_isTranscribing,
                  minLines: 1,
                  maxLines: 1,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(5000),
                  ],
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (widget.enabled && !isBusy) {
                      widget.onSubmit();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _isTranscribing
                        ? 'Memproses transkripsi suara...'
                        : widget.enabled
                        ? (isVoice
                              ? 'Bicara via mic atau ketik jawaban...'
                              : 'Ketik jawaban interview kamu...')
                        : 'Tunggu pewawancara AI...',
                    filled: false,
                    isDense: true,
                    hintMaxLines: 1,
                    hintStyle: GoogleFonts.dmSans(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: widget.enabled && !isBusy
                        ? const Color(0xFF00225E)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (widget.enabled && !isBusy)
                        Positioned.fill(
                          top: 2,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF00225E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        bottom: widget.enabled && !isBusy ? 2 : 0,
                        child: Material(
                          color: widget.enabled && !isBusy
                              ? const Color(0xFF0D49B5)
                              : Colors.grey.withAlpha(50),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.enabled && !isBusy
                                ? widget.onSubmit
                                : null,
                            child: Center(
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: widget.enabled && !isBusy
                                    ? Colors.white
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterviewResultView extends StatelessWidget {
  const _InterviewResultView({
    required this.config,
    required this.summary,
    required this.latestEvaluation,
    required this.onStartNew,
    required this.onBackToPractice,
  });

  final InterviewLaunchConfig config;
  final InterviewFinalSummary? summary;
  final InterviewEvaluation? latestEvaluation;
  final VoidCallback onStartNew;
  final VoidCallback onBackToPractice;

  @override
  Widget build(BuildContext context) {
    final InterviewFinalSummary? result = summary;
    return SingleChildScrollView(
      key: const ValueKey<String>('interview-result-view'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ResultHero(config: config, result: result),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (result != null) ...<Widget>[
                  if (result.dimensions.hasScores) ...<Widget>[
                    const _ResultSectionTitle(
                      icon: Icons.analytics_outlined,
                      title: 'Performa jawaban',
                    ),
                    const SizedBox(height: 10),
                    _ResultPanel(
                      panelKey: const ValueKey<String>('result-dimensions'),
                      child: _DimensionGrid(dimensions: result.dimensions),
                    ),
                  ],
                  if (result.strengths.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    _ResultPanel(
                      panelKey: const ValueKey<String>('result-strengths'),
                      accentColor: AppColors.levelUpTeal,
                      accentFill: const Color(0xFFE2F7F6),
                      child: _FeedbackList(
                        title: 'Yang sudah kuat',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.levelUpTeal,
                        items: result.strengths,
                      ),
                    ),
                  ],
                  if (result.improvements.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _ResultPanel(
                      panelKey: const ValueKey<String>('result-improvements'),
                      accentColor: AppColors.fireGold,
                      accentFill: const Color(0xFFFFEEDB),
                      child: _FeedbackList(
                        title: 'Fokus perbaikan',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.fireGold,
                        items: result.improvements,
                      ),
                    ),
                  ],
                ],
                if ((latestEvaluation?.suggestedRewrite ?? '')
                    .trim()
                    .isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _SuggestedRewrite(
                    key: const ValueKey<String>('result-suggested-rewrite'),
                    text: latestEvaluation!.suggestedRewrite!.trim(),
                    title: 'Contoh jawaban yang lebih kuat',
                  ),
                ],
                const SizedBox(height: 24),
                _ResultPrimaryButton(
                  buttonKey: const ValueKey<String>('result-start-new'),
                  icon: Icons.replay_rounded,
                  label: 'MULAI INTERVIEW BARU',
                  onPressed: onStartNew,
                ),
                const SizedBox(height: 10),
                _ResultSecondaryButton(
                  buttonKey: const ValueKey<String>('result-back-practice'),
                  icon: Icons.arrow_back_rounded,
                  label: 'KEMBALI KE LATIHAN',
                  onPressed: onBackToPractice,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.config, required this.result});

  final InterviewLaunchConfig config;
  final InterviewFinalSummary? result;

  @override
  Widget build(BuildContext context) {
    final double? score = result?.overallScore;
    final Color scoreColor = score == null
        ? AppColors.fireGold
        : _resultScoreColor(score);
    final Color badgeColor = score == null
        ? const Color(0xFFFFF1DF)
        : _resultScoreBadgeColor(score);
    final Color badgeTextColor = score == null
        ? const Color(0xFF8A4A12)
        : _resultScoreBadgeTextColor(score);
    return Container(
      key: const ValueKey<String>('interview-result-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D49B5),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xFF00266F),
            blurRadius: 0,
            offset: Offset(0, 7),
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
                  color: AppColors.levelUpTeal.withAlpha(40),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.levelUpTeal),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'INTERVIEW SELESAI',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFFFC477),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(42)),
                ),
                child: Text(
                  _humanizeInterviewMode(config.mode).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Hasil interviewmu',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            config.targetRole,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withAlpha(190),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _ResultScoreRing(score: score, color: scoreColor),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey<String>('interview-result-status'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeTextColor.withAlpha(80)),
            ),
            child: Text(
              score == null
                  ? 'Ringkasan belum tersedia'
                  : _resultScoreLabel(score),
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result == null
                ? 'Hasil akan tampil setelah evaluasi selesai.'
                : '${result!.answerCount} jawaban telah dinilai',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultScoreRing extends StatelessWidget {
  const _ResultScoreRing({required this.score, required this.color});

  final double? score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double progress = ((score ?? 0) / 100).clamp(0, 1);
    return SizedBox.square(
      key: const ValueKey<String>('interview-result-score'),
      dimension: 126,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: 126,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 10,
              color: Colors.white.withAlpha(28),
            ),
          ),
          SizedBox.square(
            dimension: 126,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.transparent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                score == null ? '--' : score!.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'DARI 100',
                style: TextStyle(
                  color: Colors.white.withAlpha(165),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultSectionTitle extends StatelessWidget {
  const _ResultSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.warriorNavy, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.child,
    this.panelKey,
    this.accentColor,
    this.accentFill,
  });

  final Widget child;
  final Key? panelKey;
  final Color? accentColor;
  final Color? accentFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: panelKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentFill ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (accentColor ?? AppColors.warriorNavy).withAlpha(48),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor?.withAlpha(80) ?? const Color(0xFFD7DAE0),
            blurRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ResultSectionTitle(icon: icon, title: title),
        const SizedBox(height: 10),
        for (int index = 0; index < items.length; index++) ...<Widget>[
          Text(
            items[index],
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (index < items.length - 1)
            Divider(height: 18, color: color.withAlpha(34)),
        ],
      ],
    );
  }
}

class _SuggestedRewrite extends StatelessWidget {
  const _SuggestedRewrite({required this.text, required this.title, super.key});

  final String text;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7559D4).withAlpha(65)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFFB9A9E8),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF7559D4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.warriorNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPrimaryButton extends StatelessWidget {
  const _ResultPrimaryButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF0A35F),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 8,
            child: Material(
              color: const Color(0xFFFFD7A3),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: buttonKey,
                onTap: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: const Color(0xFFC66B24), size: 19),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFC66B24),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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

class _ResultSecondaryButton extends StatelessWidget {
  const _ResultSecondaryButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFD7DAE0),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 6,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: buttonKey,
                onTap: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: AppColors.warriorNavy, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.warriorNavy,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
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

Color _resultScoreColor(double score) {
  if (score >= 75) {
    return AppColors.levelUpTeal;
  }
  if (score >= 55) {
    return AppColors.fireGold;
  }
  return const Color(0xFFFF8A4C);
}

Color _resultScoreBadgeColor(double score) {
  if (score >= 75) {
    return const Color(0xFFDDF7F3);
  }
  if (score >= 55) {
    return const Color(0xFFFFF0D8);
  }
  return const Color(0xFFFFE5D8);
}

Color _resultScoreBadgeTextColor(double score) {
  if (score >= 75) {
    return const Color(0xFF006A70);
  }
  if (score >= 55) {
    return const Color(0xFF8B5200);
  }
  return const Color(0xFFA33B16);
}

String _resultScoreLabel(double score) {
  if (score >= 85) {
    return 'Sangat siap';
  }
  if (score >= 75) {
    return 'Siap';
  }
  if (score >= 55) {
    return 'Cukup siap';
  }
  return 'Perlu lebih banyak latihan';
}

class _InterviewConfirmationDialog extends StatelessWidget {
  const _InterviewConfirmationDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmFill,
    required this.confirmShadow,
    required this.confirmForeground,
  });

  final IconData icon;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final Color confirmFill;
  final Color confirmShadow;
  final Color confirmForeground;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey<String>('interview-confirmation-dialog'),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.scholarCream,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xFFC9CFD9),
              blurRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: confirmFill,
                shape: BoxShape.circle,
                border: Border.all(color: confirmForeground.withAlpha(50)),
              ),
              child: Icon(icon, color: confirmForeground, size: 27),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: AppColors.warriorNavy,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _InterviewDialogAction(
                    actionKey: const ValueKey<String>(
                      'interview-confirmation-cancel',
                    ),
                    label: cancelLabel,
                    fill: Colors.white,
                    shadow: const Color(0xFFD7DCE4),
                    foreground: AppColors.warriorNavy,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InterviewDialogAction(
                    actionKey: const ValueKey<String>(
                      'interview-confirmation-confirm',
                    ),
                    label: confirmLabel,
                    fill: confirmFill,
                    shadow: confirmShadow,
                    foreground: confirmForeground,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InterviewDialogAction extends StatelessWidget {
  const _InterviewDialogAction({
    required this.actionKey,
    required this.label,
    required this.fill,
    required this.shadow,
    required this.foreground,
    required this.onTap,
  });

  final Key actionKey;
  final String label;
  final Color fill;
  final Color shadow;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: shadow,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          key: actionKey,
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterviewSheetHandle extends StatelessWidget {
  const _InterviewSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey<String>('interview-sheet-handle'),
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.warriorNavy.withAlpha(35),
          borderRadius: BorderRadius.circular(999),
        ),
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

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.scholarCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                    const _InterviewSheetHandle(),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Riwayat Interview',
                            style: TextStyle(
                              color: AppColors.warriorNavy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          key: const ValueKey<String>('session-history-close'),
                          tooltip: 'Tutup riwayat',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    Text(
                      'Sesi aktif baru: ${config.companyName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        key: const ValueKey<String>('interview-session-list'),
                        padding: const EdgeInsets.fromLTRB(1, 0, 1, 8),
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
                          final String summaryText =
                              session.finalSummary == null
                              ? 'Belum diselesaikan'
                              : 'Skor ${session.finalSummary!.overallScore.toStringAsFixed(1)}';

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey<String>(
                                'interview-session-${session.sessionId}',
                              ),
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => onOpenSession(session),
                              child: Ink(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFFE4F7F5)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.levelUpTeal
                                        : AppColors.warriorNavy.withAlpha(24),
                                    width: isCurrent ? 1.6 : 1,
                                  ),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0xFFD9DEE7),
                                      blurRadius: 0,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.warriorNavy.withAlpha(
                                          12,
                                        ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Aktif',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.levelUpTeal,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${session.targetRole} • ${_humanizeInterviewMode(session.mode)}',
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
                        onPressed: () =>
                            ref.invalidate(interviewSessionsProvider),
                        child: const Text('Muat ulang'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionDetailSheet extends ConsumerStatefulWidget {
  const _SessionDetailSheet({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_SessionDetailSheet> createState() =>
      _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  final ScrollController _transcriptController = ScrollController();

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<InterviewSessionDetailRecord> detailAsync = ref.watch(
      interviewSessionDetailProvider(widget.sessionId),
    );

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.scholarCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: detailAsync.when(
              data: (InterviewSessionDetailRecord detail) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _InterviewSheetHandle(),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        IconButton.filledTonal(
                          key: const ValueKey<String>('session-detail-back'),
                          tooltip: 'Kembali ke riwayat',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Detail sesi',
                            style: TextStyle(
                              color: AppColors.warriorNavy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      '${detail.targetRole} - ${_humanizeInterviewMode(detail.mode)}',
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
                          : Scrollbar(
                              key: const ValueKey<String>(
                                'interview-session-scrollbar',
                              ),
                              controller: _transcriptController,
                              thumbVisibility: true,
                              radius: const Radius.circular(999),
                              thickness: 4,
                              child: ListView.separated(
                                key: const ValueKey<String>(
                                  'interview-session-transcript',
                                ),
                                controller: _transcriptController,
                                padding: const EdgeInsets.only(right: 10),
                                itemCount: detail.messages.length,
                                separatorBuilder:
                                    (BuildContext context, int index) =>
                                        const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final InterviewMessage message =
                                      detail.messages[index];
                                  return _SessionTranscriptTile(
                                    message: message,
                                  );
                                },
                              ),
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
                          interviewSessionDetailProvider(widget.sessionId),
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
        color: isCandidate ? const Color(0xFFE5F7F5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCandidate
              ? AppColors.levelUpTeal.withAlpha(36)
              : AppColors.warriorNavy.withAlpha(20),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isCandidate
                ? const Color(0xFFAADDD8)
                : const Color(0xFFD9DEE7),
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
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
                color: const Color(0xFFFFEBD9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC58D)),
              ),
              child: Text(
                'Catatan untuk jawabanmu: ${message.evaluation!.coachNote!}',
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
  const Map<String, String> companyNames = <String, String>{
    'adhi-karya': 'PT Adhi Karya (Persero) Tbk',
    'bank-indonesia': 'Bank Indonesia',
    'bank-mandiri': 'PT Bank Mandiri (Persero) Tbk',
    'garuda-indonesia': 'PT Garuda Indonesia (Persero) Tbk',
    'injourney': 'PT Aviasi Pariwisata Indonesia (Persero)',
    'kementerian-keuangan': 'Kementerian Keuangan Republik Indonesia',
    'kereta-api-indonesia': 'PT Kereta Api Indonesia (Persero)',
    'perusahaan-listrik-negara': 'PT PLN (Persero)',
    'pertamina': 'PT Pertamina (Persero)',
  };
  if (companyId.trim().isEmpty) {
    return 'Sesi Interview';
  }
  final String normalized = companyId.trim().toLowerCase();
  if (companyNames.containsKey(normalized)) {
    return companyNames[normalized]!;
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

String _humanizeInterviewMode(String mode) {
  switch (mode.trim().toLowerCase()) {
    case 'coaching':
      return 'Coaching';
    case 'realistic':
      return 'Realistik';
    default:
      return mode.trim().isEmpty ? 'Interview' : mode.trim();
  }
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
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? const Color(0xFF0D49B5) : AppColors.scholarCream,
        border: Border.all(
          color: isUser
              ? Colors.white.withAlpha(180)
              : AppColors.levelUpTeal.withAlpha(120),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isUser ? const Color(0xFF00225E) : AppColors.levelUpTeal)
                .withAlpha(50),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        size: 16,
        color: isUser ? Colors.white : AppColors.levelUpTeal,
      ),
    );
  }
}
