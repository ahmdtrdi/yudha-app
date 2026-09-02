import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/learning/presentation/widgets/learning_explanation_sheet.dart';
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
          onAction: () => context.go(AppRoutes.solo),
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
                  _SectionHeading(
                    'Ringkasan belajar',
                    explanation: _evidenceStrengthExplanation(data.accuracy),
                  ),
                  const SizedBox(height: 10),
                  _SummaryGrid(dashboard: data, narrow: narrow),
                  const SizedBox(height: 22),
                  const _SectionHeading('Peta keterampilan'),
                  const SizedBox(height: 10),
                  _SkillMap(states: data.skillStates),
                  const SizedBox(height: 22),
                  _SectionHeading(
                    'Retensi',
                    explanation: _retentionExplanation(data.retention),
                  ),
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
      AppRoutes.solo,
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        value.objectiveLabel.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.fireGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    LearningInfoButton(
                      explanation: _recommendationExplanation(value),
                      color: Colors.white,
                    ),
                  ],
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
                    _Pill(
                      'Kekuatan bukti ${_evidenceStrength(value.confidence)}',
                    ),
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
  const _SectionHeading(this.label, {this.explanation});
  final String label;
  final LearningExplanation? explanation;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (explanation != null) LearningInfoButton(explanation: explanation!),
    ],
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
            '${dashboard.coverage.coveredSkillCount}/${dashboard.coverage.requiredSkillCount} skill · kekuatan bukti ${_evidenceStrength(dashboard.coverage.confidence)}',
        explanation: _coverageExplanation(dashboard.coverage),
      ),
      _MetricCard(
        label: 'Akurasi mandiri (mentah)',
        value: _percent(dashboard.accuracy.value),
        detail:
            '${dashboard.accuracy.attemptCount} percobaan · kekuatan bukti ${_evidenceStrength(dashboard.accuracy.confidence)}',
        explanation: _accuracyExplanation(dashboard.accuracy),
      ),
      _MetricCard(
        label: 'Rasio tempo',
        value: dashboard.pace.value == null
            ? 'Belum cukup data'
            : '${dashboard.pace.value!.toStringAsFixed(2)}×',
        detail:
            '${dashboard.pace.attemptCount} percobaan layak · kekuatan bukti ${_evidenceStrength(dashboard.pace.confidence)}',
        explanation: _paceExplanation(dashboard.pace),
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
    required this.explanation,
  });
  final String label;
  final String value;
  final String detail;
  final LearningExplanation explanation;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            LearningInfoButton(explanation: explanation),
          ],
        ),
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
                          '${_status(state.status, state.confidence)} · ${state.accuracy.attemptCount} bukti mandiri\nKekuatan bukti ${_evidenceStrength(state.confidence)} · ${_trendLabel(state.trendPercentagePoints)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: <Widget>[
                      Text(
                        _percent(state.accuracy.value),
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      LearningInfoButton(
                        explanation: _skillExplanation(state),
                        color: tone,
                      ),
                    ],
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

String _evidenceStrength(String value) => switch (value) {
  'high' => 'tinggi',
  'medium' => 'sedang',
  _ => 'rendah',
};

String _trendLabel(double? value) {
  if (value == null) return 'tren belum tersedia';
  final String sign = value > 0 ? '+' : '';
  return 'tren $sign${value.toStringAsFixed(1)} poin';
}

LearningExplanation _recommendationExplanation(
  LearningRecommendation recommendation,
) {
  return LearningExplanation(
    title: 'Mengapa ini direkomendasikan?',
    definition:
        'Sistem memilih satu tindakan Solo yang paling berguna berdasarkan bukti belajarmu saat ini.',
    counts:
        'Akurasi yang distabilkan, kekuatan bukti, retensi, cakupan, rasio tempo, kepentingan kurikulum, dan latihan 24 jam terakhir.',
    doesNotCount:
        'Kepercayaan diri pribadi. Hasil PvP dan Assessment tetap menjadi konteks terpisah dan tidak menjadi tindakan utama.',
    formula:
        'Urutan aturan: perbaiki akurasi → ulasan jatuh tempo → tambah bukti/cakupan → bangun kelancaran → jaga cakupan.',
    example:
        '${recommendation.reasonHeadline}. ${recommendation.reasonDescription} Kekuatan bukti saat ini ${_evidenceStrength(recommendation.confidence)}.',
    evidenceWindow:
        'Menggunakan proyeksi terbaru dari maksimal 20 bukti layak per skill. Rekomendasi dihitung ulang saat ada bukti baru dan berlaku sampai ${recommendation.expiresAt == null ? 'waktu kedaluwarsa berikutnya' : _dateTime(recommendation.expiresAt!)}.',
  );
}

LearningExplanation _evidenceStrengthExplanation(LearningMetric metric) {
  return LearningExplanation(
    title: 'Kekuatan bukti',
    definition:
        'Ini menunjukkan seberapa dapat diandalkan datanya—bukan seberapa percaya diri kamu.',
    counts:
        'Jumlah percobaan mandiri pada soal baru, jumlah soal unik, variasi tingkat kesulitan, dan seberapa baru buktinya. Ringkasan memakai kekuatan terendah dari skill yang berkontribusi.',
    doesNotCount:
        'Perasaan yakin, keberanian menjawab, atau nilai kepribadian. Akurasi tinggi dengan data yang sedikit tetap dapat berkekuatan rendah.',
    formula:
        'Per skill—tinggi: ≥15 percobaan, ≥8 soal unik, ≥2 tingkat kesulitan, bukti terbaru ≤14 hari. Sedang: ≥5 percobaan, ≥3 soal unik, bukti terbaru ≤30 hari. Selain itu: rendah.',
    example:
        'Totalmu ${metric.attemptCount} percobaan dari ${metric.uniqueQuestionCount} soal unik. Kekuatan ringkasan ${_evidenceStrength(metric.confidence)} karena sistem memakai penilaian paling konservatif di antara skill yang berkontribusi.',
    evidenceWindow:
        'Dihitung dari maksimal 20 percobaan layak terbaru per skill; batas kebaruan 14 atau 30 hari diterapkan pada bukti terakhir.',
  );
}

LearningExplanation _accuracyExplanation(
  LearningMetric metric, {
  double? smoothedAccuracy,
}) {
  final String rawExample = metric.attemptCount == 0
      ? 'Belum ada percobaan layak untuk dihitung.'
      : '${metric.correctCount} benar ÷ ${metric.attemptCount} percobaan = ${_percent(metric.value)} akurasi mentah.';
  final String smoothedExample = smoothedAccuracy == null
      ? 'Akurasi yang distabilkan ditampilkan pada detail tiap skill ketika datanya tersedia.'
      : 'Dengan penyeimbang +2/+4, akurasi yang distabilkan menjadi ${_percent(smoothedAccuracy)}.';
  return LearningExplanation(
    title: 'Akurasi mentah dan distabilkan',
    definition:
        'Akurasi mandiri adalah hasil percobaan pertama tanpa petunjuk. “Soal baru” berarti soal itu belum pernah kamu lihat sebelumnya.',
    counts:
        'Jawaban valid, percobaan pertama, tanpa petunjuk. Akurasi unseen-independent hanya memakai soal baru yang belum pernah dilihat.',
    doesNotCount:
        'Percobaan dengan petunjuk, pengulangan soal, jawaban yang dibatalkan, dan bukti yang tidak dapat diklasifikasikan dengan aman.',
    formula:
        'Mentah = benar ÷ percobaan layak × 100%. Distabilkan = (benar + 2) ÷ (percobaan + 4) × 100%; angka distabilkan dipakai untuk status dan rekomendasi.',
    example: '$rawExample $smoothedExample',
    evidenceWindow:
        'Maksimal 20 percobaan layak terbaru per skill. Data ini dihitung per ${metric.asOf == null ? 'pembaruan terakhir' : _dateTime(metric.asOf!)}.',
  );
}

LearningExplanation _paceExplanation(LearningPace pace) {
  final double? value = pace.value;
  final String interpretation = value == null
      ? 'Belum ada cukup percobaan dengan waktu yang dapat dibandingkan.'
      : value == 1
      ? 'Rasio ${value.toStringAsFixed(2)}× berarti waktumu sama dengan waktu acuan.'
      : value < 1
      ? 'Rasio ${value.toStringAsFixed(2)}× berarti sekitar ${((1 - value) * 100).round()}% lebih cepat dari acuan.'
      : 'Rasio ${value.toStringAsFixed(2)}× berarti sekitar ${((value - 1) * 100).round()}% lebih lambat dari acuan.';
  return LearningExplanation(
    title: 'Rasio tempo',
    definition:
        'Rasio tempo membandingkan waktu jawaban efektifmu dengan waktu acuan soal. Nilai 1,00× berarti sesuai acuan.',
    counts:
        'Percobaan valid tanpa petunjuk yang memiliki waktu respons efektif dan waktu acuan yang dapat dibandingkan.',
    doesNotCount:
        'Waktu latar belakang, timing yang tidak valid, percobaan berbantuan, atau soal tanpa acuan yang sesuai.',
    formula:
        'Rasio tiap percobaan = waktu efektif ÷ waktu acuan. Rasio skill = median seluruh rasio yang dapat dibandingkan.',
    example:
        '$interpretation Berdasarkan ${pace.attemptCount} percobaan layak.',
    evidenceWindow:
        'Maksimal 20 percobaan layak terbaru per skill. Jenis acuan: ${pace.baselineType == 'calibrated'
            ? 'waktu soal terkalibrasi'
            : pace.baselineType == 'personal'
            ? 'riwayat pribadimu'
            : 'belum tersedia'}.',
  );
}

LearningExplanation _coverageExplanation(LearningCoverage coverage) {
  return LearningExplanation(
    title: 'Cakupan kurikulum',
    definition:
        'Cakupan menunjukkan berapa banyak skill wajib yang sudah memiliki bukti belajar yang cukup.',
    counts:
        'Skill wajib yang aktif dan memiliki sedikitnya tiga soal unik layak.',
    doesNotCount:
        'Skill opsional, skill nonaktif, pengulangan soal yang sama, atau satu percobaan tunggal.',
    formula: 'Skill wajib tercakup ÷ seluruh skill wajib aktif × 100%.',
    example:
        '${coverage.coveredSkillCount} dari ${coverage.requiredSkillCount} skill wajib tercakup = ${_percent(coverage.value)}.',
    evidenceWindow:
        'Mengikuti proyeksi terbaru tiap skill dari maksimal 20 percobaan layak; bukan hanya jumlah aktivitas 30 hari.',
  );
}

LearningExplanation _retentionExplanation(List<LearningRetention> items) {
  final LearningRetention? sample = items.isEmpty ? null : items.first;
  final String example = sample == null
      ? 'Belum ada jadwal ulasan. Jadwal pertama muncul tujuh hari setelah bukti kuat terbentuk.'
      : sample.attemptCount == 0
      ? '${sample.skillId} dijadwalkan untuk ulasan pada ${sample.reviewDueAt == null ? 'tanggal yang akan ditentukan' : _date(sample.reviewDueAt!)}.'
      : '${sample.skillId}: ${sample.attemptCount} percobaan retensi menghasilkan ${_percent(sample.accuracy)}.';
  return LearningExplanation(
    title: 'Retensi',
    definition:
        'Retensi mengukur apakah pemahaman tetap bertahan saat diuji lagi setelah jeda.',
    counts:
        'Percobaan tertunda yang valid, mandiri, tanpa petunjuk, dan memakai soal baru yang setara.',
    doesNotCount:
        'Latihan langsung setelah belajar, pengulangan berbantuan, dan soal yang sudah pernah dilihat.',
    formula:
        'Jawaban benar pada ulasan tertunda ÷ seluruh percobaan ulasan tertunda yang layak × 100%. Nilai di bawah 75% memicu perhatian.',
    example: example,
    evidenceWindow:
        'Ulasan dijadwalkan tujuh hari setelah bukti kuat. Bukti kuat yang lebih tua dari 30 hari juga dapat memicu ulasan.',
  );
}

LearningExplanation _skillExplanation(LearningSkillState state) {
  final String pace = state.paceRatio == null
      ? 'rasio tempo belum tersedia'
      : 'rasio tempo ${state.paceRatio!.toStringAsFixed(2)}×';
  return LearningExplanation(
    title: 'Cara membaca ${state.label}',
    definition:
        'Status skill merangkum akurasi mandiri, kestabilan data, tempo, dan kebutuhan ulasan.',
    counts:
        'Percobaan valid pertama tanpa petunjuk; metrik “soal baru” juga mensyaratkan soal belum pernah dilihat.',
    doesNotCount:
        'Petunjuk dan soal berulang tidak masuk akurasi soal-baru mandiri. Bukti PvP dan Assessment tetap terpisah.',
    formula:
        'Mentah = benar ÷ percobaan. Distabilkan = (benar + 2) ÷ (percobaan + 4). Tren = akurasi 10 terbaru − 10 sebelumnya.',
    example:
        '${state.accuracy.correctCount}/${state.accuracy.attemptCount} benar = ${_percent(state.accuracy.value)} mentah; ${_percent(state.smoothedAccuracy)} distabilkan; $pace; ${_trendLabel(state.trendPercentagePoints)}; kekuatan bukti ${_evidenceStrength(state.confidence)}.',
    evidenceWindow:
        'Status memakai maksimal 20 percobaan layak terbaru. Tren baru muncul setelah tersedia dua blok yang masing-masing berisi 10 percobaan.',
  );
}

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
