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
          'PERKEMBANGAN BELAJAR',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: switch ((state.status, dashboard)) {
        (LearningViewStatus.loading, null) => const _LearningSkeleton(),
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
              final bool narrow = constraints.maxWidth < 600;
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
                  _DashboardContext(target: data.target, asOf: data.asOf),
                  const SizedBox(height: 12),
                  _NextActionCard(
                    recommendation: data.nextAction,
                    sampleSize: _findSkill(
                      data.skillStates,
                      data.nextAction?.skillId,
                    )?.accuracy.attemptCount,
                    onStart: data.nextAction?.runnable == true
                        ? () => _startRecommendation(data.nextAction!)
                        : null,
                    onCustomize: () => context.go(AppRoutes.solo),
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeading('Ringkasan kemajuan'),
                  const SizedBox(height: 10),
                  _SummaryGrid(dashboard: data, narrow: narrow),
                  const SizedBox(height: 18),
                  const _SectionHeading('Temuan utama'),
                  const SizedBox(height: 10),
                  _InsightPanel(dashboard: data),
                  const SizedBox(height: 22),
                  _DashboardSections(
                    dashboard: data,
                    narrow: narrow,
                    onSkillTap: _openSkillDetail,
                    onPracticeSkill: _startSkill,
                    onOpenCompetition: () => context.go(AppRoutes.pvp),
                  ),
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
    final PracticeLaunchRequest request = PracticeLaunchRequest(
      focus:
          recommendation.subcategory ??
          recommendation.category ??
          recommendation.skillLabel,
      recommendationId: recommendation.id,
    );
    if (recommendation.compatibilityAdapter == 'practice_fixed_five') {
      context.go(AppRoutes.soloTopics, extra: request);
      return;
    }
    context.go(AppRoutes.solo);
  }

  void _startSkill(LearningSkillState skill) {
    context.go(
      AppRoutes.soloTopics,
      extra: PracticeLaunchRequest(
        focus: skill.subcategory ?? skill.category ?? skill.label,
      ),
    );
  }

  void _openSkillDetail(LearningSkillState skill) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.scholarCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _SkillDetailSheet(
        skill: skill,
        onPractice: () {
          Navigator.of(context).pop();
          _startSkill(skill);
        },
      ),
    );
  }
}

class _LearningSkeleton extends StatelessWidget {
  const _LearningSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat dashboard perkembangan belajar',
    child: ListView(
      key: const ValueKey<String>('learning-skeleton'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _block(24, width: 180),
        const SizedBox(height: 14),
        _block(210),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(child: _block(112)),
            const SizedBox(width: 10),
            Expanded(child: _block(112)),
            const SizedBox(width: 10),
            Expanded(child: _block(112)),
          ],
        ),
        const SizedBox(height: 20),
        _block(132),
        const SizedBox(height: 20),
        _block(240),
      ],
    ),
  );

  static Widget _block(double height, {double? width}) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.warriorNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.recommendation,
    required this.sampleSize,
    required this.onStart,
    required this.onCustomize,
  });

  final LearningRecommendation? recommendation;
  final int? sampleSize;
  final VoidCallback? onStart;
  final VoidCallback onCustomize;

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
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, color: AppColors.fireGold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada rekomendasi. Selesaikan Solo untuk menambah bukti belajar.',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onCustomize,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x669CC2FF)),
                  ),
                  child: const Text('Atur sesi Solo'),
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
                    _Pill(_mechanic(value.mechanicMode)),
                    _Pill('Bukti ${_confidence(value.confidence)}'),
                    if (sampleSize != null) _Pill('$sampleSize bukti mandiri'),
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
                          ? value.compatibilityAdapter == 'practice_fixed_five'
                                ? 'Mulai Practice 5 soal'
                                : 'Mulai sesi Solo'
                          : 'Belum dapat dijalankan',
                    ),
                  ),
                ),
                if (!value.runnable &&
                    value.unavailableReason != null) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    value.unavailableReason!,
                    style: const TextStyle(
                      color: Color(0xFFD7E5FF),
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onCustomize,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x669CC2FF)),
                    ),
                    child: const Text('Atur sendiri'),
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

class _DashboardContext extends StatelessWidget {
  const _DashboardContext({required this.target, required this.asOf});

  final String target;
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.levelUpTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          target.toUpperCase(),
          style: const TextStyle(
            color: AppColors.levelUpTeal,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const Text(
        '30 hari terakhir',
        style: TextStyle(
          color: AppColors.textStrong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (asOf != null)
        Text(
          'Diperbarui ${_date(asOf!)}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
    ],
  );
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.dashboard});

  final LearningDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final List<_LearningInsight> insights = _buildInsights(dashboard);
    return Container(
      key: const ValueKey<String>('learning-insights'),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < insights.length; index++) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: insights[index].color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    insights[index].icon,
                    size: 18,
                    color: insights[index].color,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    insights[index].message,
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (index < insights.length - 1)
              const Divider(height: 22, color: Color(0x1400215A)),
          ],
        ],
      ),
    );
  }
}

class _LearningInsight {
  const _LearningInsight(this.icon, this.color, this.message);

  final IconData icon;
  final Color color;
  final String message;
}

List<_LearningInsight> _buildInsights(LearningDashboard dashboard) {
  final List<_LearningInsight> result = <_LearningInsight>[];
  final Set<String> mentionedSkills = <String>{};
  final List<LearningRetention> due = dashboard.retention
      .where((LearningRetention item) => item.status == 'due')
      .toList(growable: false);
  if (due.isNotEmpty) {
    final LearningRetention first = due.first;
    result.add(
      _LearningInsight(
        Icons.event_repeat_rounded,
        const Color(0xFF7A4DA3),
        '${due.length} skill sudah waktunya diulas. Mulai dari ${first.label}${first.attemptCount == 0 ? ' sambil mengumpulkan bukti tertunda.' : ' berdasarkan ${first.correctCount}/${first.attemptCount} bukti tertunda · bukti ${_confidence(first.confidence)}.'}',
      ),
    );
    mentionedSkills.add(first.skillId);
  }

  final List<LearningSkillState> declining =
      dashboard.skillStates
          .where(
            (LearningSkillState state) =>
                state.trendPercentagePoints != null &&
                state.trendPercentagePoints! < 0 &&
                !mentionedSkills.contains(state.skillId),
          )
          .toList()
        ..sort(
          (LearningSkillState left, LearningSkillState right) => left
              .trendPercentagePoints!
              .compareTo(right.trendPercentagePoints!),
        );
  if (result.length < 2 && declining.isNotEmpty) {
    final LearningSkillState state = declining.first;
    result.add(
      _LearningInsight(
        Icons.trending_down_rounded,
        const Color(0xFFD16B32),
        '${state.label} berubah ${_signedPoints(state.trendPercentagePoints!)} dibanding 10 bukti sebelumnya · bukti ${_confidence(state.confidence)}.',
      ),
    );
    mentionedSkills.add(state.skillId);
  }

  final List<LearningSkillState> slow =
      dashboard.skillStates
          .where(
            (LearningSkillState state) =>
                state.paceRatio != null &&
                state.paceRatio! > 1.2 &&
                !mentionedSkills.contains(state.skillId),
          )
          .toList()
        ..sort(
          (LearningSkillState left, LearningSkillState right) =>
              right.paceRatio!.compareTo(left.paceRatio!),
        );
  if (result.length < 2 && slow.isNotEmpty) {
    final LearningSkillState state = slow.first;
    result.add(
      _LearningInsight(
        Icons.speed_rounded,
        AppColors.fireGold,
        '${state.label} berada di ${state.paceRatio!.toStringAsFixed(2)}× pace ${_baseline(state.paceBaselineType)} dari ${state.paceAttemptCount} jawaban layak.',
      ),
    );
    mentionedSkills.add(state.skillId);
  }

  final List<LearningSkillState> improving =
      dashboard.skillStates
          .where(
            (LearningSkillState state) =>
                state.trendPercentagePoints != null &&
                state.trendPercentagePoints! > 0 &&
                !mentionedSkills.contains(state.skillId),
          )
          .toList()
        ..sort(
          (LearningSkillState left, LearningSkillState right) => right
              .trendPercentagePoints!
              .compareTo(left.trendPercentagePoints!),
        );
  if (result.length < 2 && improving.isNotEmpty) {
    final LearningSkillState state = improving.first;
    result.add(
      _LearningInsight(
        Icons.trending_up_rounded,
        AppColors.levelUpTeal,
        '${state.label} meningkat ${_signedPoints(state.trendPercentagePoints!)} dibanding 10 bukti sebelumnya · bukti ${_confidence(state.confidence)}.',
      ),
    );
  }

  if (result.isEmpty) {
    final int missing =
        dashboard.coverage.requiredSkillCount -
        dashboard.coverage.coveredSkillCount;
    result.add(
      _LearningInsight(
        Icons.auto_graph_rounded,
        AppColors.levelUpTeal,
        missing > 0
            ? 'Data masih dikumpulkan. Jawab soal dari $missing skill yang belum memiliki cukup bukti agar rekomendasi makin akurat.'
            : 'Belum ada dua blok bukti yang setara untuk membaca tren. Lanjutkan latihan rutin untuk membuka insight perkembangan.',
      ),
    );
  }
  return result.take(2).toList(growable: false);
}

class _DashboardSections extends StatelessWidget {
  const _DashboardSections({
    required this.dashboard,
    required this.narrow,
    required this.onSkillTap,
    required this.onPracticeSkill,
    required this.onOpenCompetition,
  });

  final LearningDashboard dashboard;
  final bool narrow;
  final ValueChanged<LearningSkillState> onSkillTap;
  final ValueChanged<LearningSkillState> onPracticeSkill;
  final VoidCallback onOpenCompetition;

  @override
  Widget build(BuildContext context) {
    final Widget skills = _SectionBlock(
      title: 'Peta skill',
      child: _SkillMap(
        states: dashboard.skillStates,
        recommendationSkillId: dashboard.nextAction?.skillId,
        onTap: onSkillTap,
      ),
    );
    final Widget supporting = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionBlock(
          title: 'Retensi',
          child: _RetentionPanel(
            items: dashboard.retention,
            skillStates: dashboard.skillStates,
            onPractice: onPracticeSkill,
          ),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: 'Konsistensi 30 hari',
          child: _ActivityPanel(activity: dashboard.activity),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: 'Assessment',
          child: _AssessmentPanel(assessment: dashboard.assessment),
        ),
        const SizedBox(height: 22),
        _SectionBlock(
          title: 'Competition',
          child: _CompetitionPanel(
            competition: dashboard.competition,
            onOpen: onOpenCompetition,
          ),
        ),
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[skills, const SizedBox(height: 22), supporting],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: skills),
        const SizedBox(width: 18),
        Expanded(flex: 2, child: supporting),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _SectionHeading(title),
      const SizedBox(height: 10),
      child,
    ],
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
            '${dashboard.accuracy.correctCount}/${dashboard.accuracy.attemptCount} jawaban · bukti ${_confidence(dashboard.accuracy.confidence)}',
      ),
      _MetricCard(
        label: 'Pace',
        value: dashboard.pace.value == null
            ? 'Belum cukup data'
            : '${dashboard.pace.value!.toStringAsFixed(2)}×',
        detail:
            '${dashboard.pace.attemptCount} jawaban layak · ${_baseline(dashboard.pace.baselineType)} · bukti ${_confidence(dashboard.pace.confidence)}',
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
  const _SkillMap({
    required this.states,
    required this.recommendationSkillId,
    required this.onTap,
  });
  final List<LearningSkillState> states;
  final String? recommendationSkillId;
  final ValueChanged<LearningSkillState> onTap;

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) {
      return const _EmptyPanel(
        'Belum ada skill aktif. Sinkronisasi konten perlu diselesaikan.',
      );
    }
    final List<LearningSkillState> sorted =
        List<LearningSkillState>.from(states)..sort((
          LearningSkillState left,
          LearningSkillState right,
        ) {
          final bool leftRecommended = left.skillId == recommendationSkillId;
          final bool rightRecommended = right.skillId == recommendationSkillId;
          if (leftRecommended != rightRecommended) {
            return leftRecommended ? -1 : 1;
          }
          final int priority = _skillPriority(
            left,
          ).compareTo(_skillPriority(right));
          return priority != 0 ? priority : left.label.compareTo(right.label);
        });
    final Map<String, List<LearningSkillState>> groups =
        <String, List<LearningSkillState>>{};
    for (final LearningSkillState state in sorted) {
      final String category = state.category?.toUpperCase() ?? 'LAINNYA';
      groups.putIfAbsent(category, () => <LearningSkillState>[]).add(state);
    }
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x1400215A)),
      ),
      child: Column(
        children: groups.entries
            .map((entry) {
              final bool containsRecommendation = entry.value.any(
                (LearningSkillState state) =>
                    state.skillId == recommendationSkillId,
              );
              return ExpansionTile(
                key: ValueKey<String>('learning-skill-group-${entry.key}'),
                initiallyExpanded: containsRecommendation || groups.length == 1,
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    color: AppColors.warriorNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${entry.value.length} skill',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                children: entry.value
                    .map(
                      (LearningSkillState state) => _SkillRow(
                        state: state,
                        recommended: state.skillId == recommendationSkillId,
                        onTap: () => onTap(state),
                      ),
                    )
                    .toList(growable: false),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.state,
    required this.recommended,
    required this.onTap,
  });

  final LearningSkillState state;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = _statusColor(state.status, state.confidence);
    final String status = _status(state.status, state.confidence);
    return Semantics(
      button: true,
      label:
          '${state.label}, $status, ${state.accuracy.correctCount} dari ${state.accuracy.attemptCount} jawaban mandiri, bukti ${_confidence(state.confidence)}',
      child: Material(
        color: recommended
            ? AppColors.fireGold.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey<String>('learning-skill-${state.skillId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(_statusIcon(state.status), color: tone, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              state.label,
                              style: const TextStyle(
                                color: AppColors.textStrong,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (recommended) ...<Widget>[
                            const SizedBox(width: 6),
                            const _MiniBadge('Fokus utama'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$status · ${state.accuracy.correctCount}/${state.accuracy.attemptCount} · bukti ${_confidence(state.confidence)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _percent(state.accuracy.value),
                  style: TextStyle(color: tone, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.fireGold.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8B460E),
        fontSize: 8,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _SkillDetailSheet extends StatelessWidget {
  const _SkillDetailSheet({required this.skill, required this.onPractice});

  final LearningSkillState skill;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final Color tone = _statusColor(skill.status, skill.confidence);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x3300215A),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(skill.status), color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        skill.label,
                        style: const TextStyle(
                          color: AppColors.textStrong,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_status(skill.status, skill.confidence)} · bukti ${_confidence(skill.confidence)}',
                        style: TextStyle(
                          color: tone,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DetailMetric(
                  label: 'Akurasi mandiri',
                  value: _percent(skill.accuracy.value),
                  detail:
                      '${skill.accuracy.correctCount}/${skill.accuracy.attemptCount} jawaban',
                ),
                _DetailMetric(
                  label: 'Tren 10 vs 10',
                  value: skill.trendPercentagePoints == null
                      ? '—'
                      : _signedPoints(skill.trendPercentagePoints!),
                  detail: skill.trendPercentagePoints == null
                      ? 'Belum cukup bukti setara'
                      : 'percentage point',
                ),
                _DetailMetric(
                  label: 'Median pace',
                  value: skill.medianResponseTimeMs == null
                      ? '—'
                      : _duration(skill.medianResponseTimeMs!),
                  detail: skill.paceRatio == null
                      ? 'Baseline belum tersedia'
                      : '${skill.paceRatio!.toStringAsFixed(2)}× ${_baseline(skill.paceBaselineType)}',
                ),
                _DetailMetric(
                  label: 'Penggunaan hint',
                  value: _percent(skill.hintRate),
                  detail:
                      '${skill.assistedAccuracy.attemptCount} jawaban berbantuan',
                ),
                _DetailMetric(
                  label: 'Timeout',
                  value: _percent(skill.timeoutRate),
                  detail: '${skill.paceAttemptCount} jawaban pace-valid',
                ),
                _DetailMetric(
                  label: 'Terakhir dilatih',
                  value: skill.lastPracticedAt == null
                      ? '—'
                      : _date(skill.lastPracticedAt!),
                  detail: skill.coverageSufficient
                      ? 'Cakupan bukti cukup'
                      : 'Cakupan bukti belum cukup',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warriorNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Mode yang disarankan: ${_mechanic(skill.recommendedMechanic)}. Status ini berasal dari bukti Solo dan bukan prediksi kelulusan.',
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPractice,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Latih ${skill.label}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: 154,
    padding: const EdgeInsets.all(12),
    decoration: _panelDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _RetentionPanel extends StatelessWidget {
  const _RetentionPanel({
    required this.items,
    required this.skillStates,
    required this.onPractice,
  });
  final List<LearningRetention> items;
  final List<LearningSkillState> skillStates;
  final ValueChanged<LearningSkillState> onPractice;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyPanel(
        'Belum ada jadwal ulasan. Jadwal muncul setelah bukti kuat yang masih segar.',
      );
    }
    final List<LearningRetention> sorted = List<LearningRetention>.from(items)
      ..sort((LearningRetention left, LearningRetention right) {
        if (left.status == 'due' && right.status != 'due') return -1;
        if (left.status != 'due' && right.status == 'due') return 1;
        return (left.reviewDueAt ?? DateTime(9999)).compareTo(
          right.reviewDueAt ?? DateTime(9999),
        );
      });
    final int dueCount = sorted
        .where((LearningRetention item) => item.status == 'due')
        .length;
    return Container(
      decoration: _panelDecoration,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    dueCount == 0
                        ? 'Tidak ada review jatuh tempo'
                        : '$dueCount review jatuh tempo',
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  dueCount == 0
                      ? Icons.task_alt_rounded
                      : Icons.notification_important_rounded,
                  color: dueCount == 0
                      ? AppColors.levelUpTeal
                      : AppColors.fireGold,
                ),
              ],
            ),
          ),
          ...sorted.take(3).map((LearningRetention item) {
            final LearningSkillState? skill = _findSkill(
              skillStates,
              item.skillId,
            );
            return ListTile(
              dense: true,
              leading: Icon(
                item.status == 'due'
                    ? Icons.notification_important_rounded
                    : Icons.event_repeat_rounded,
                color: item.status == 'due'
                    ? AppColors.fireGold
                    : AppColors.levelUpTeal,
              ),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                item.reviewDueAt == null
                    ? 'Tanggal ulasan belum tersedia'
                    : '${item.status == 'due' ? 'Seharusnya diulas' : 'Ulasan'} ${_date(item.reviewDueAt!)}${item.attemptCount > 0 ? ' · ${item.accuracy?.round() ?? '—'}% (${item.correctCount}/${item.attemptCount}) · bukti ${_confidence(item.confidence)}' : ''}',
              ),
              trailing: item.status == 'due' && skill != null
                  ? IconButton(
                      tooltip: 'Latih ${item.label}',
                      onPressed: () => onPractice(skill),
                      icon: const Icon(Icons.play_arrow_rounded),
                    )
                  : Text(
                      item.status == 'due' ? 'Jatuh tempo' : 'Terjadwal',
                      style: const TextStyle(fontSize: 10),
                    ),
            );
          }),
          if (sorted.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showSchedule(context, sorted),
                icon: const Icon(Icons.list_alt_rounded, size: 17),
                label: Text('Lihat semua ${sorted.length} jadwal'),
              ),
            ),
        ],
      ),
    );
  }

  void _showSchedule(BuildContext context, List<LearningRetention> sorted) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: sorted.length,
        itemBuilder: (BuildContext context, int index) {
          final LearningRetention item = sorted[index];
          return ListTile(
            leading: Icon(
              item.status == 'due'
                  ? Icons.notification_important_rounded
                  : Icons.event_repeat_rounded,
            ),
            title: Text(item.label),
            subtitle: Text(
              item.reviewDueAt == null
                  ? 'Tanggal belum tersedia'
                  : '${item.status == 'due' ? 'Jatuh tempo' : 'Terjadwal'} ${_date(item.reviewDueAt!)}',
            ),
          );
        },
      ),
    );
  }
}

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({required this.assessment});
  final LearningAssessment assessment;

  @override
  Widget build(BuildContext context) {
    if (assessment.status == 'not_available') {
      return const _EmptyPanel(
        'Assessment belum tersedia. Kemajuan ini berasal dari bukti Solo dan belum divalidasi melalui Assessment.',
        icon: Icons.fact_check_outlined,
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.verified_rounded, color: AppColors.levelUpTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _assessmentStatus(assessment.status),
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _percent(assessment.score),
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (assessment.attemptCount != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              '${assessment.correctCount ?? '—'}/${assessment.attemptCount} jawaban · bukti ${_confidence(assessment.confidence)} · ${assessment.occurredAt == null ? 'tanggal tidak tersedia' : _date(assessment.occurredAt!)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
          if (assessment.baseline != null &&
              assessment.latest != null) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DetailMetric(
                  label: 'Baseline',
                  value: _percent(assessment.baseline!.score),
                  detail:
                      '${assessment.baseline!.correctCount ?? '—'}/${assessment.baseline!.attemptCount ?? '—'} · ${assessment.baseline!.occurredAt == null ? 'tanggal —' : _date(assessment.baseline!.occurredAt!)}',
                ),
                _DetailMetric(
                  label: 'Terbaru',
                  value: _percent(assessment.latest!.score),
                  detail:
                      '${assessment.latest!.correctCount ?? '—'}/${assessment.latest!.attemptCount ?? '—'} · ${assessment.latest!.occurredAt == null ? 'tanggal —' : _date(assessment.latest!.occurredAt!)}',
                ),
              ],
            ),
          ],
          if (assessment.improvementPercentagePoints != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.levelUpTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Perubahan dari baseline: ${_signedPoints(assessment.improvementPercentagePoints!)}.',
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (assessment.categoryBreakdown.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ...assessment.categoryBreakdown
                .take(3)
                .map(
                  (LearningBreakdown item) => Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text(_humanizeIdentifier(item.label))),
                        Text(
                          '${_percent(item.value)} · ${item.correctCount == null || item.attemptCount == null ? 'count —' : '${item.correctCount}/${item.attemptCount}'} · bukti ${_confidence(item.confidence)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity});
  final LearningActivity activity;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 16,
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
        const Divider(height: 24, color: Color(0x1400215A)),
        Row(
          children: <Widget>[
            const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.fireGold,
              size: 20,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${activity.streak.current} hari streak · terbaik ${activity.streak.best}',
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (activity.weeklyActivity.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text(
            'Soal per pekan',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _WeeklyBars(items: activity.weeklyActivity),
        ],
        if (activity.recentSessions.isNotEmpty) ...<Widget>[
          const Divider(height: 24, color: Color(0x1400215A)),
          const Text(
            'Sesi terbaru',
            style: TextStyle(
              color: AppColors.textStrong,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          ...activity.recentSessions
              .take(5)
              .map(
                (LearningRecentSession session) =>
                    _RecentSessionRow(session: session),
              ),
        ],
      ],
    ),
  );
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.items});
  final List<LearningActivityWeek> items;

  @override
  Widget build(BuildContext context) {
    final int maximum = items.fold<int>(
      1,
      (int current, LearningActivityWeek item) =>
          item.questionsAnswered > current ? item.questionsAnswered : current,
    );
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.indexed
            .map((entry) {
              final int index = entry.$1;
              final LearningActivityWeek item = entry.$2;
              final double ratio = item.questionsAnswered / maximum;
              return Expanded(
                child: Semantics(
                  label:
                      'Pekan ${index + 1}, ${item.questionsAnswered} soal dijawab',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${item.questionsAnswered}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: 52 * ratio + 5,
                          decoration: BoxDecoration(
                            color: index == items.length - 1
                                ? AppColors.levelUpTeal
                                : AppColors.warriorNavy.withValues(alpha: 0.52),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'P${index + 1}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RecentSessionRow extends StatelessWidget {
  const _RecentSessionRow({required this.session});
  final LearningRecentSession session;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      children: <Widget>[
        Icon(
          _completionIcon(session.completionState),
          size: 18,
          color: _completionColor(session.completionState),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                session.skillLabels.isEmpty
                    ? _mechanic(session.mechanicMode)
                    : session.skillLabels.take(2).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_completion(session.completionState)} · ${session.lastActivityAt == null ? '—' : _date(session.lastActivityAt!)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
            ],
          ),
        ),
        Text(
          session.accuracy == null
              ? '—'
              : '${session.correctCount}/${session.attemptCount}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
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
  const _CompetitionPanel({required this.competition, required this.onOpen});
  final LearningCompetition competition;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.sports_kabaddi_rounded, color: AppColors.fireGold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_tier(competition.tier)} · ${competition.rankPoints} poin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${competition.matchRecord.wins}M ${competition.matchRecord.losses}K ${competition.matchRecord.draws}S · ${_percent(competition.accuracy.value)} (${competition.accuracy.correctCount}/${competition.accuracy.attemptCount}) · bukti ${_confidence(competition.accuracy.confidence)}',
                    style: const TextStyle(
                      color: Color(0xFFC4D3ED),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          competition.soloComparison?.gapPercentagePoints == null
              ? 'Bukti PvP tetap dipisahkan dari bukti Solo. Perbandingan muncul setelah kedua sampel memadai.'
              : 'Selisih akurasi Solo terhadap PvP ${_signedPoints(competition.soloComparison!.gapPercentagePoints!)}.',
          style: const TextStyle(
            color: Color(0xFFC4D3ED),
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x55FFFFFF)),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Buka detail PvP'),
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

IconData _statusIcon(String value) => switch (value) {
  'needs_repair' => Icons.build_circle_outlined,
  'developing' => Icons.trending_up_rounded,
  'needs_review' => Icons.event_repeat_rounded,
  'needs_fluency' => Icons.speed_rounded,
  'secure' => Icons.verified_rounded,
  _ => Icons.hourglass_top_rounded,
};

int _skillPriority(LearningSkillState state) {
  if (state.confidence == 'low') return 5;
  return switch (state.status) {
    'needs_review' => 0,
    'needs_repair' => 1,
    'needs_fluency' => 2,
    'developing' => 3,
    'collecting_data' => 4,
    'secure' => 6,
    _ => 5,
  };
}

LearningSkillState? _findSkill(
  List<LearningSkillState> states,
  String? skillId,
) {
  if (skillId == null) return null;
  for (final LearningSkillState state in states) {
    if (state.skillId == skillId) return state;
  }
  return null;
}

String _baseline(String? value) => switch (value) {
  'calibrated' => 'baseline terkalibrasi',
  'personal' => 'baseline personal',
  _ => 'baseline belum tersedia',
};

String _mechanic(String? value) => switch (value) {
  'focus' => 'Focus',
  'speed' => 'Speed',
  _ => 'Standard',
};

String _signedPoints(double value) {
  final String sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} poin persentase';
}

String _duration(int milliseconds) {
  if (milliseconds < 1000) return '$milliseconds md';
  return '${(milliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} dtk';
}

String _assessmentStatus(String value) => switch (value) {
  'validated' => 'Kemajuan tervalidasi',
  'baseline_recorded' => 'Baseline tercatat',
  'needs_revalidation' => 'Perlu validasi ulang',
  _ => 'Bukti Assessment terbatas',
};

String _completion(String value) => switch (value) {
  'policy_completed' || 'compatibility_completed' => 'Selesai',
  'user_stopped' => 'Dihentikan',
  'question_inventory_exhausted' => 'Soal habis',
  'abandoned' => 'Ditinggalkan',
  _ => 'Berjalan',
};

IconData _completionIcon(String value) => switch (value) {
  'policy_completed' || 'compatibility_completed' => Icons.check_circle_rounded,
  'user_stopped' => Icons.stop_circle_outlined,
  'abandoned' => Icons.error_outline_rounded,
  _ => Icons.timelapse_rounded,
};

Color _completionColor(String value) => switch (value) {
  'policy_completed' || 'compatibility_completed' => AppColors.levelUpTeal,
  'abandoned' => const Color(0xFFD16B32),
  _ => AppColors.textMuted,
};

String _tier(String value) => switch (value) {
  'legend' => 'Legend',
  'elite' => 'Elite',
  'warrior' => 'Warrior',
  _ => 'Rookie',
};

String _humanizeIdentifier(String value) {
  final List<String> words = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  return words
      .map((String word) {
        final String upper = word.toUpperCase();
        if (<String>{
          'TWK',
          'TIU',
          'TKP',
          'TKD',
          'AKHLAK',
          'NKRI',
        }.contains(upper)) {
          return upper;
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

DateTime _wib(DateTime value) => value.toUtc().add(const Duration(hours: 7));

String _date(DateTime value) {
  final DateTime wib = _wib(value);
  return '${wib.day.toString().padLeft(2, '0')}/${wib.month.toString().padLeft(2, '0')}/${wib.year}';
}

String _dateTime(DateTime value) {
  final DateTime wib = _wib(value);
  return '${_date(value)} ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')} WIB';
}
