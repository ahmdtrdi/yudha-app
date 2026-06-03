import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
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
    final InterviewMessage? currentQuestion = state.currentQuestion;

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
                    .start(),
              ),
            Expanded(
              child: state.status == InterviewViewStatus.starting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: state.messages.length + (isBusy ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index < state.messages.length) {
                          return _ChatBubble(message: state.messages[index]);
                        }
                        return const _TypingBubble();
                      },
                    ),
            ),
            if (state.latestEvaluation != null)
              _EvaluationStrip(evaluation: state.latestEvaluation!),
            _AnswerComposer(
              controller: _answerController,
              enabled: state.canSubmit,
              isBusy: isBusy,
              onSubmit: _submitAnswer,
            ),
          ],
        ),
      ),
    );
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final InterviewMessage message;

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
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
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

class _AnswerComposer extends StatelessWidget {
  const _AnswerComposer({
    required this.controller,
    required this.enabled,
    required this.isBusy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Ketik jawaban interview kamu...'
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
          FilledButton(
            onPressed: enabled && !isBusy ? onSubmit : null,
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
      .split('_')
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
