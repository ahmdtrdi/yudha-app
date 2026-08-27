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
      AppRoutes.interview,
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
                    onStartNew: () => context.go(AppRoutes.interviewSetup),
                    onBackToPractice: () => context.go(AppRoutes.practice),
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
                      '${config.targetRole} - ${_humanizeInterviewMode(config.mode)}',
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
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withAlpha(160),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        children: <Widget>[
          Container(
            key: const ValueKey<String>('interview-voice-mode-card'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(38)),
            ),
            child: Row(
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
                        'Interview Suara',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        copy.subtitle,
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
                Icon(
                  state.livePhase == LiveInterviewPhase.degraded
                      ? Icons.wifi_off_rounded
                      : Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            copy.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          _VoiceVisualizerOrb(isActive: isActive),
          const SizedBox(height: 24),
          Flexible(
            child: Container(
              key: const ValueKey<String>('interview-question-surface'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(36)),
              ),
              child: _ScrollableInterviewQuestion(
                text:
                    currentQuestion?.text ??
                    'Menyiapkan pertanyaan interview...',
              ),
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
          if (state.liveErrorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              state.liveErrorMessage!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFE0C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
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
          const SizedBox(height: 6),
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
      'Panggilan terputus',
      'Sambungkan lagi atau lanjutkan sesi yang sama lewat teks.',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PushToTalkButton(
          canStart: phase == LiveInterviewPhase.readyToAnswer,
          isSpeaking: phase == LiveInterviewPhase.candidateSpeaking,
          recordingDuration: recordingDuration,
          onStart: onPushToTalkStart,
          onEnd: onPushToTalkEnd,
          onCancel: onPushToTalkCancel,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _LiveCallButton(
              key: const ValueKey<String>('live-interview-end-call'),
              icon: Icons.call_end_rounded,
              label: 'Akhiri',
              background: const Color(0xFFE94D4D),
              onPressed: onEndCall,
            ),
            if (showReconnect) ...<Widget>[
              const SizedBox(width: 20),
              _LiveCallButton(
                key: const ValueKey<String>('live-interview-reconnect'),
                icon: Icons.refresh_rounded,
                label: 'Sambung',
                background: const Color(0xFF159A9C),
                onPressed: onReconnect,
              ),
            ],
          ],
        ),
        TextButton.icon(
          key: const ValueKey<String>('live-interview-text-fallback'),
          onPressed: onTextFallback,
          icon: const Icon(Icons.keyboard_alt_outlined, size: 17),
          label: const Text('Beralih ke teks'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 228,
          height: 68,
          decoration: BoxDecoration(
            color: recording
                ? const Color(0xFFE94D4D)
                : enabled
                ? Colors.white.withAlpha(38)
                : Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: recording
                  ? const Color(0xFFFFD4D4)
                  : Colors.white.withAlpha(enabled ? 85 : 35),
              width: 1.5,
            ),
            boxShadow: recording
                ? <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFE94D4D).withAlpha(90),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                recording ? Icons.mic_rounded : Icons.touch_app_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (recording)
                      Text(
                        '$elapsed / 01:30',
                        key: const ValueKey<String>(
                          'live-interview-recording-duration',
                        ),
                        style: TextStyle(
                          color: Colors.white.withAlpha(210),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
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
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: background,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.38,
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
          size: const Size.square(180),
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
                  if (isUser && message.evaluation != null) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showFeedback(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.scholarCream,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.insights_outlined, size: 16),
                      label: const Text(
                        'Lihat umpan balik',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '...',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 24,
          height: 0.6,
          letterSpacing: 0,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(70)),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: AppColors.scholarCream,
                child: Text(
                  evaluation.overallScore.toStringAsFixed(0),
                  style: const TextStyle(
                    color: AppColors.warriorNavy,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Umpan Balik Jawaban',
                      style: TextStyle(
                        color: AppColors.warriorNavy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.warriorNavy,
              ),
            ],
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withAlpha(70),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.scholarCream,
                        child: Text(
                          evaluation.overallScore.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppColors.warriorNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Umpan Balik Jawaban',
                          style: TextStyle(
                            color: AppColors.warriorNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
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
                          Text(
                            note,
                            style: const TextStyle(
                              color: AppColors.textStrong,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  score.label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                score.value.toStringAsFixed(0),
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 5,
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
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.redAccent.withAlpha(60)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.warriorNavy.withAlpha(38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(42),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isVoice && _voiceMessage != null) ...<Widget>[
            Row(
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
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_pendingAudioBytes != null && !_isTranscribing)
                  TextButton(
                    onPressed: _transcribePendingAudio,
                    child: const Text('Coba lagi'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              if (isVoice) ...<Widget>[
                IconButton(
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
                  onPressed: widget.enabled && !isBusy ? _startRecording : null,
                ),
              ],
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('interview-answer-field'),
                  controller: widget.controller,
                  enabled: widget.enabled && !_isTranscribing,
                  minLines: 1,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 12.5,
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
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
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
                FilledButton(
                  onPressed: widget.enabled && !isBusy ? widget.onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D49B5),
                    shape: const CircleBorder(),
                    minimumSize: const Size.square(42),
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Icon(Icons.send_rounded),
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
