import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_launch_request.dart';

class LearningPage extends ConsumerStatefulWidget {
  const LearningPage({super.key});

  @override
  ConsumerState<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends ConsumerState<LearningPage> {
  String? _shownRecommendationId;

  @override
  Widget build(BuildContext context) {
    final LearningState state = ref.watch(learningControllerProvider);
    final LearningDashboard? dashboard = state.dashboard;
    _recordShown(dashboard?.nextAction);

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D49B5),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'LEARNING',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: switch ((state.status, dashboard)) {
        (LearningViewStatus.loading, null) => const Center(
          child: CircularProgressIndicator(),
        ),
        (LearningViewStatus.unavailable, _) => _LearningMessage(
          icon: Icons.lock_clock_rounded,
          title: 'Learning segera hadir',
          message:
              state.errorMessage ??
              'Analitik baru sedang disiapkan. Practice tetap dapat digunakan.',
          actionLabel: 'Buka Practice',
          onAction: () => context.go(AppRoutes.practice),
        ),
        (LearningViewStatus.error, null) => _LearningMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Learning belum dapat dimuat',
          message: state.errorMessage ?? 'Periksa koneksi lalu coba lagi.',
          actionLabel: 'Coba lagi',
          onAction: ref.read(learningControllerProvider.notifier).load,
        ),
        (_, null) => _LearningMessage(
          icon: Icons.insights_rounded,
          title: 'Belum ada ringkasan',
          message: 'Tarik ulang untuk menyiapkan ringkasan Learning.',
          actionLabel: 'Muat ulang',
          onAction: ref.read(learningControllerProvider.notifier).load,
        ),
        (_, final LearningDashboard data?) => RefreshIndicator(
          onRefresh: ref.read(learningControllerProvider.notifier).load,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool narrow = constraints.maxWidth < 520;
              return ListView(
                key: const ValueKey<String>('learning-dashboard'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 24,
                  18,
                  narrow ? 16 : 24,
                  28,
                ),
                children: <Widget>[
                  if (state.status == LearningViewStatus.loading)
                    const LinearProgressIndicator(minHeight: 3),
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
                  _NextActionCard(
                    recommendation: data.nextAction,
                    onStart: data.nextAction?.runnable == true
                        ? () => _startRecommendation(data.nextAction!)
                        : null,
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeading('Ringkasan 30 hari'),
                  const SizedBox(height: 10),
                  _SummaryGrid(dashboard: data, narrow: narrow),
                  const SizedBox(height: 22),
                  const _SectionHeading('Peta keterampilan'),
                  const SizedBox(height: 10),
                  _SkillMap(states: data.skillStates),
                  const SizedBox(height: 22),
                  const _SectionHeading('Retensi'),
                  const SizedBox(height: 10),
                  _RetentionPanel(items: data.retention),
                  const SizedBox(height: 22),
                  const _SectionHeading('Assessment'),
                  const SizedBox(height: 10),
                  _AssessmentPanel(assessment: data.assessment),
                  const SizedBox(height: 22),
                  const _SectionHeading('Aktivitas'),
                  const SizedBox(height: 10),
                  _ActivityPanel(activity: data.activity),
                  const SizedBox(height: 22),
                  const _SectionHeading('Competition'),
                  const SizedBox(height: 10),
                  _CompetitionPanel(competition: data.competition),
                  if (data.asOf != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Data per ${_dateTime(data.asOf!)} · ${data.calculationVersion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      },
    );
  }

  void _recordShown(LearningRecommendation? recommendation) {
    if (recommendation == null || _shownRecommendationId == recommendation.id) {
      return;
    }
    _shownRecommendationId = recommendation.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(learningControllerProvider.notifier).recordShown(recommendation);
    });
  }

  Future<void> _startRecommendation(
    LearningRecommendation recommendation,
  ) async {
    final bool accepted = await ref
        .read(learningControllerProvider.notifier)
        .accept(recommendation);
    if (!mounted) return;
    if (!accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rekomendasi belum dapat dimulai.')),
      );
      return;
    }
    context.go(
      AppRoutes.practice,
      extra: PracticeLaunchRequest(
        focus:
            recommendation.subcategory ??
            recommendation.category ??
            recommendation.skillLabel,
        recommendationId: recommendation.id,
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.recommendation, required this.onStart});

  final LearningRecommendation? recommendation;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final LearningRecommendation? value = recommendation;
    return Container(
      key: const ValueKey<String>('learning-next-action'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFF001E51), offset: Offset(0, 6)),
        ],
      ),
      child: value == null
          ? const Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded, color: AppColors.fireGold),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada rekomendasi. Selesaikan Practice untuk menambah bukti belajar.',
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value.objectiveLabel.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.fireGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.reasonHeadline.isEmpty
                      ? value.skillLabel
                      : value.reasonHeadline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.reasonDescription,
                  style: const TextStyle(
                    color: Color(0xFFD7E5FF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(value.skillLabel),
                    _Pill('Bukti ${_confidence(value.confidence)}'),
                    if (value.compatibilityLabel != null)
                      _Pill(value.compatibilityLabel!),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      value.runnable
                          ? 'Mulai Practice 5 soal'
                          : 'Belum dapat dijalankan',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.warriorNavy,
      fontSize: 16,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.dashboard, required this.narrow});
  final LearningDashboard dashboard;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      _MetricCard(
        label: 'Cakupan kurikulum',
        value: _percent(dashboard.coverage.value),
        detail:
            '${dashboard.coverage.coveredSkillCount}/${dashboard.coverage.requiredSkillCount} skill · ${_confidence(dashboard.coverage.confidence)}',
      ),
      _MetricCard(
        label: 'Akurasi mandiri',
        value: _percent(dashboard.accuracy.value),
        detail:
            '${dashboard.accuracy.attemptCount} percobaan · ${_confidence(dashboard.accuracy.confidence)}',
      ),
      _MetricCard(
        label: 'Pace',
        value: dashboard.pace.value == null
            ? 'Belum cukup data'
            : '${dashboard.pace.value!.toStringAsFixed(2)}×',
        detail:
            '${dashboard.pace.attemptCount} percobaan layak · ${_confidence(dashboard.pace.confidence)}',
      ),
    ];
    if (narrow) {
      return Column(
        children:
            cards
                .expand(
                  (Widget card) => <Widget>[card, const SizedBox(height: 10)],
                )
                .toList()
              ..removeLast(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          cards
              .expand(
                (Widget card) => <Widget>[
                  Expanded(child: card),
                  const SizedBox(width: 10),
                ],
              )
              .toList()
            ..removeLast(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _SkillMap extends StatelessWidget {
  const _SkillMap({required this.states});
  final List<LearningSkillState> states;

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) {
      return const _EmptyPanel(
        'Belum ada skill aktif. Sinkronisasi konten perlu diselesaikan.',
      );
    }
    return Column(
      children: states
          .map((LearningSkillState state) {
            final Color tone = _statusColor(state.status, state.confidence);
            return Container(
              key: ValueKey<String>('learning-skill-${state.skillId}'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _panelDecoration,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tone,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.label,
                          style: const TextStyle(
                            color: AppColors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_status(state.status, state.confidence)} · ${state.accuracy.attemptCount} bukti mandiri',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _percent(state.accuracy.value),
                    style: TextStyle(color: tone, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _RetentionPanel extends StatelessWidget {
  const _RetentionPanel({required this.items});
  final List<LearningRetention> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyPanel(
        'Belum ada jadwal ulasan. Jadwal muncul setelah bukti kuat yang masih segar.',
      );
    }
    return Container(
      decoration: _panelDecoration,
      child: Column(
        children: items
            .map((LearningRetention item) {
              return ListTile(
                leading: Icon(
                  item.status == 'due'
                      ? Icons.notification_important_rounded
                      : Icons.event_repeat_rounded,
                  color: item.status == 'due'
                      ? AppColors.fireGold
                      : AppColors.levelUpTeal,
                ),
                title: Text(item.skillId),
                subtitle: Text(
                  item.reviewDueAt == null
                      ? 'Tanggal ulasan belum tersedia'
                      : 'Ulasan ${_date(item.reviewDueAt!)}',
                ),
                trailing: Text(
                  item.status == 'due' ? 'Jatuh tempo' : 'Terjadwal',
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({required this.assessment});
  final LearningAssessment assessment;

  @override
  Widget build(BuildContext context) => _EmptyPanel(
    assessment.status == 'not_available'
        ? 'Assessment belum tersedia. Hasil Practice tidak diubah menjadi skor Assessment.'
        : 'Skor ${assessment.score?.toStringAsFixed(1) ?? '-'} dari ${assessment.attemptCount ?? 0} jawaban.',
    icon: assessment.status == 'not_available'
        ? Icons.fact_check_outlined
        : Icons.verified_rounded,
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity});
  final LearningActivity activity;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Wrap(
      spacing: 20,
      runSpacing: 14,
      children: <Widget>[
        _ActivityValue('${activity.activeLearningDays}', 'hari aktif'),
        _ActivityValue('${activity.questionsAnswered}', 'soal dijawab'),
        _ActivityValue('${activity.sessionCount}', 'sesi'),
        _ActivityValue(
          activity.activeLearningMinutes == null
              ? '—'
              : activity.activeLearningMinutes!.toStringAsFixed(1),
          'menit terukur',
        ),
      ],
    ),
  );
}

class _ActivityValue extends StatelessWidget {
  const _ActivityValue(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
      ],
    ),
  );
}

class _CompetitionPanel extends StatelessWidget {
  const _CompetitionPanel({required this.competition});
  final LearningCompetition competition;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Row(
      children: <Widget>[
        const Icon(Icons.sports_kabaddi_rounded, color: AppColors.fireGold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_percent(competition.accuracy.value)} akurasi',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${competition.accuracy.attemptCount} jawaban PvP · dipisahkan dari bukti Solo',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message, {this.icon = Icons.info_outline_rounded});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panelDecoration,
    child: Row(
      children: <Widget>[
        Icon(icon, color: AppColors.levelUpTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _LearningMessage extends StatelessWidget {
  const _LearningMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: AppColors.warriorNavy),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

final BoxDecoration _panelDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0x1400215A)),
);

String _percent(double? value) => value == null ? '—' : '${value.round()}%';

String _confidence(String value) => switch (value) {
  'high' => 'tinggi',
  'medium' => 'sedang',
  _ => 'rendah',
};

String _status(String value, String confidence) {
  if (confidence == 'low') return 'Mengumpulkan data';
  return switch (value) {
    'needs_repair' => 'Perlu diperbaiki',
    'developing' => 'Berkembang',
    'needs_review' => 'Perlu diulas',
    'needs_fluency' => 'Bangun kelancaran',
    'secure' => 'Kuat',
    _ => 'Mengumpulkan data',
  };
}

Color _statusColor(String value, String confidence) {
  if (confidence == 'low') return const Color(0xFF6C89A5);
  return switch (value) {
    'needs_repair' => const Color(0xFFD97928),
    'developing' || 'needs_fluency' => AppColors.fireGold,
    'needs_review' => const Color(0xFF7A4DA3),
    'secure' => AppColors.levelUpTeal,
    _ => const Color(0xFF6C89A5),
  };
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateTime(DateTime value) =>
    '${_date(value)} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
