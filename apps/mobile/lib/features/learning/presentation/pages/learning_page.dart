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
  void initState() {
    super.initState();
    // Solo can finish while this app-wide provider still holds the snapshot
    // loaded by Lobby or Profile. Entering Learning always requests the
    // canonical post-session snapshot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(learningControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LearningState state = ref.watch(learningControllerProvider);
    final LearningDashboard? dashboard = state.dashboard;
    _recordShown(dashboard?.nextAction);

    return Scaffold(
      backgroundColor: _LearningClay.cream,
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xFF1B59BA),
        foregroundColor: Colors.white,
        centerTitle: true,
        titleSpacing: 20,
        flexibleSpace: Container(
          key: const ValueKey<String>('learning-clay-header'),
          color: const Color(0xFF1B59BA),
        ),
        title: Text(
          'LEARNING CENTER',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: _LearningBackdrop(
        child: switch ((state.status, dashboard)) {
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
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _UnifiedLearningHero(
                      recommendation: data.nextAction,
                      sampleSize: _findSkill(
                        data.skillStates,
                        data.nextAction?.skillId,
                      )?.accuracy.attemptCount,
                      onStart: data.nextAction?.runnable == true
                          ? () => _startRecommendation(data.nextAction!)
                          : null,
                      onCustomize: () => context.go(AppRoutes.solo),
                      narrow: narrow,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 16 : 24,
                        18,
                        narrow ? 16 : 24,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          _SectionHeading(
                            'Ringkasan kemajuan',
                            explanation: _evidenceStrengthExplanation(
                              data.accuracy,
                            ),
                          ),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        },
      ),
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

abstract final class _LearningClay {
  static const Color cream = Color(0xFFFFF8EC);
  static const Color paper = Color(0xFFFFFDF8);
  static const Color blue = Color(0xFF1270E3);
  static const Color cyan = Color(0xFF75DCEB);
  static const Color mint = Color(0xFF79D7C5);
  static const Color peach = Color(0xFFFFB878);
  static const Color lavender = Color(0xFFC7B8F5);
  static const Color clayShadow = Color(0xFFD9D1C4);
}

class _LearningBackdrop extends StatelessWidget {
  const _LearningBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey<String>('learning-clay-background'),
    children: <Widget>[
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFFFFBF3), _LearningClay.cream],
            ),
          ),
        ),
      ),
      Positioned(
        top: 34,
        right: -38,
        child: _BackdropOrb(
          size: 118,
          color: _LearningClay.cyan.withValues(alpha: 0.18),
        ),
      ),
      Positioned(
        top: 310,
        left: -54,
        child: _BackdropOrb(
          size: 138,
          color: _LearningClay.peach.withValues(alpha: 0.15),
        ),
      ),
      Positioned.fill(child: child),
    ],
  );
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
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

class _UnifiedLearningHero extends StatelessWidget {
  const _UnifiedLearningHero({
    required this.recommendation,
    required this.sampleSize,
    required this.onStart,
    required this.onCustomize,
    required this.narrow,
  });

  final LearningRecommendation? recommendation;
  final int? sampleSize;
  final VoidCallback? onStart;
  final VoidCallback onCustomize;
  final bool narrow;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _LearningClay.cream,
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF103E8A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            child: ColoredBox(
              color: const Color(0xFF1B59BA),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: -15,
                    right: -20,
                    child: Opacity(
                      opacity: 0.07,
                      child: const Icon(
                        Icons.school_rounded,
                        size: 160,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      narrow ? 16 : 24,
                      12,
                      narrow ? 16 : 24,
                      22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox.shrink(
                          key: ValueKey<String>('learning-context-clay-card'),
                        ),
                        _NextActionCard(
                          recommendation: recommendation,
                          sampleSize: sampleSize,
                          onStart: onStart,
                          onCustomize: onCustomize,
                        ),
                      ],
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
      child: value == null
          ? Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFF3BD56),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada rekomendasi. Selesaikan Solo untuk menambah bukti belajar.',
                          style: TextStyle(color: Colors.white, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onCustomize,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x66B0D1FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Atur sesi Solo'),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: Color(0xFFFFD768),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'REKOMENDASI HARI INI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LearningInfoButton(
                      explanation: _recommendationExplanation(value),
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFF38BDF8), Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0xFF075985),
                            offset: Offset(0, 3.5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        value.reasonHeadline.isEmpty
                            ? value.skillLabel
                            : value.reasonHeadline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        value.reasonDescription,
                        style: const TextStyle(
                          color: Color(0xFFD6E6FF),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          _Pill(value.skillLabel),
                          _Pill(_mechanic(value.mechanicMode)),
                          _Pill('Bukti ${_evidenceStrength(value.confidence)}'),
                          if (sampleSize != null)
                            _Pill('$sampleSize bukti mandiri'),
                          if (value.compatibilityLabel != null)
                            _Pill(value.compatibilityLabel!),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFE5A638),
                      foregroundColor: AppColors.warriorNavy,
                      disabledBackgroundColor: const Color(0xFF6C89A5),
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFFFE3B0)),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      value.runnable
                          ? value.compatibilityAdapter == 'practice_fixed_five'
                                ? 'Mulai Practice 5 soal'
                                : 'Mulai sesi Solo'
                          : 'Belum dapat dijalankan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (!value.runnable &&
                    value.unavailableReason != null) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    value.unavailableReason!,
                    style: const TextStyle(
                      color: Color(0xFFD6E6FF),
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
                      side: const BorderSide(color: Color(0x66B0D1FF)),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Atur sendiri',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.dashboard});

  final LearningDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final List<_LearningInsight> insights = _buildInsights(dashboard);
    return Container(
      key: const ValueKey<String>('learning-insights'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFF4DE), Color(0xFFFFFBF3)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFFE0C9A7), offset: Offset(0, 6)),
          BoxShadow(
            color: Color(0x1600215A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
                    color: insights[index].color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: insights[index].color.withValues(alpha: 0.25),
                        offset: const Offset(0, 3),
                      ),
                    ],
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
        '${due.length} skill sudah waktunya diulas. Mulai dari ${first.label}${first.attemptCount == 0 ? ' sambil mengumpulkan bukti tertunda.' : ' berdasarkan ${first.correctCount}/${first.attemptCount} bukti tertunda · bukti ${_evidenceStrength(first.confidence)}.'}',
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
        '${state.label} berubah ${_signedPoints(state.trendPercentagePoints!)} dibanding 10 bukti sebelumnya · bukti ${_evidenceStrength(state.confidence)}.',
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
        '${state.label} meningkat ${_signedPoints(state.trendPercentagePoints!)} dibanding 10 bukti sebelumnya · bukti ${_evidenceStrength(state.confidence)}.',
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
          explanation: _retentionExplanation(dashboard.retention),
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
  const _SectionBlock({
    required this.title,
    required this.child,
    this.explanation,
  });

  final String title;
  final Widget child;
  final LearningExplanation? explanation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _SectionHeading(title, explanation: explanation),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label, {this.explanation});
  final String label;
  final LearningExplanation? explanation;

  @override
  Widget build(BuildContext context) {
    final (IconData, Color) visual = _sectionVisual(label);
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: visual.$2,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: visual.$2.withValues(alpha: 0.45),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(visual.$1, size: 18, color: AppColors.warriorNavy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.fredoka(
              color: AppColors.warriorNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (explanation != null) LearningInfoButton(explanation: explanation!),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.dashboard, required this.narrow});
  final LearningDashboard dashboard;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      _MetricCard(
        icon: Icons.grid_view_rounded,
        accent: const Color(0xFF38A8E8),
        bgGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF0F8FE), Color(0xFFFAFDFF)],
        ),
        borderColor: const Color(0xFFBAE3F7),
        clayShadow: const Color(0xFFA2D7F5),
        badgeColor: const Color(0xFF38A8E8),
        labelColor: const Color(0xFF1B6A9C),
        valueColor: const Color(0xFF0F4E75),
        label: 'Cakupan kurikulum',
        value: _percent(dashboard.coverage.value),
        detail:
            '${dashboard.coverage.coveredSkillCount}/${dashboard.coverage.requiredSkillCount} skill · kekuatan bukti ${_evidenceStrength(dashboard.coverage.confidence)}',
        explanation: _coverageExplanation(dashboard.coverage),
      ),
      _MetricCard(
        icon: Icons.gps_fixed_rounded,
        accent: const Color(0xFF34B882),
        bgGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF1FAF5), Color(0xFFFBFEFC)],
        ),
        borderColor: const Color(0xFFBAECCF),
        clayShadow: const Color(0xFF9DE0B9),
        badgeColor: const Color(0xFF34B882),
        labelColor: const Color(0xFF1C754E),
        valueColor: const Color(0xFF0F5435),
        label: 'Akurasi mandiri (mentah)',
        value: _percent(dashboard.accuracy.value),
        detail:
            '${dashboard.accuracy.correctCount}/${dashboard.accuracy.attemptCount} jawaban · bukti ${_evidenceStrength(dashboard.accuracy.confidence)}',
        explanation: _accuracyExplanation(dashboard.accuracy),
      ),
      _MetricCard(
        icon: Icons.speed_rounded,
        accent: const Color(0xFFE89A38),
        bgGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFF9F2), Color(0xFFFFFDFC)],
        ),
        borderColor: const Color(0xFFFED8B3),
        clayShadow: const Color(0xFFF8C697),
        badgeColor: const Color(0xFFE89A38),
        labelColor: const Color(0xFF9E541A),
        valueColor: const Color(0xFF753A0D),
        label: 'Rasio tempo',
        value: dashboard.pace.value == null
            ? 'Belum cukup data'
            : '${dashboard.pace.value!.toStringAsFixed(2)}×',
        detail:
            '${dashboard.pace.attemptCount} jawaban layak · ${_baseline(dashboard.pace.baselineType)} · bukti ${_evidenceStrength(dashboard.pace.confidence)}',
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
    required this.icon,
    required this.accent,
    required this.bgGradient,
    required this.borderColor,
    required this.clayShadow,
    required this.badgeColor,
    required this.labelColor,
    required this.valueColor,
    required this.label,
    required this.value,
    required this.detail,
    required this.explanation,
  });

  final IconData icon;
  final Color accent;
  final Gradient bgGradient;
  final Color borderColor;
  final Color clayShadow;
  final Color badgeColor;
  final Color labelColor;
  final Color valueColor;
  final String label;
  final String value;
  final String detail;
  final LearningExplanation explanation;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 122),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: bgGradient,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor, width: 1.8),
      boxShadow: <BoxShadow>[
        BoxShadow(color: clayShadow, offset: const Offset(0, 5)),
        const BoxShadow(
          color: Color(0x1400215A),
          blurRadius: 14,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: clayShadow, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            LearningInfoButton(explanation: explanation),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: TextStyle(
            color: labelColor.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
    return Container(
      decoration: _clayDecoration(),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Column(
          children: groups.entries
              .map((entry) {
                final bool containsRecommendation = entry.value.any(
                  (LearningSkillState state) =>
                      state.skillId == recommendationSkillId,
                );
                return ExpansionTile(
                  key: ValueKey<String>('learning-skill-group-${entry.key}'),
                  initiallyExpanded:
                      containsRecommendation || groups.length == 1,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  collapsedBackgroundColor: const Color(0x33EAF7FF),
                  backgroundColor: const Color(0x22EAF7FF),
                  iconColor: _LearningClay.blue,
                  collapsedIconColor: AppColors.textMuted,
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
          '${state.label}, $status, ${state.accuracy.correctCount} dari ${state.accuracy.attemptCount} jawaban mandiri, bukti ${_evidenceStrength(state.confidence)}',
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
                        '$status · ${state.accuracy.correctCount}/${state.accuracy.attemptCount} · bukti ${_evidenceStrength(state.confidence)}',
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
                        '${_status(skill.status, skill.confidence)} · bukti ${_evidenceStrength(skill.confidence)}',
                        style: TextStyle(
                          color: tone,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                LearningInfoButton(
                  explanation: _skillExplanation(skill),
                  color: tone,
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
                    : '${item.status == 'due' ? 'Seharusnya diulas' : 'Ulasan'} ${_date(item.reviewDueAt!)}${item.attemptCount > 0 ? ' · ${item.accuracy?.round() ?? '—'}% (${item.correctCount}/${item.attemptCount}) · bukti ${_evidenceStrength(item.confidence)}' : ''}',
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
              '${assessment.correctCount ?? '—'}/${assessment.attemptCount} jawaban · bukti ${_evidenceStrength(assessment.confidence)} · ${assessment.occurredAt == null ? 'tanggal tidak tersedia' : _date(assessment.occurredAt!)}',
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
                          '${_percent(item.value)} · ${item.correctCount == null || item.attemptCount == null ? 'count —' : '${item.correctCount}/${item.attemptCount}'} · bukti ${_evidenceStrength(item.confidence)}',
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
    padding: const EdgeInsets.all(16),
    decoration: _panelDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ActivityValue(
                value: '${activity.activeLearningDays}',
                label: 'Hari aktif',
                icon: Icons.calendar_today_rounded,
                accent: const Color(0xFF389AD8),
                bgGradient: const LinearGradient(
                  colors: <Color>[Color(0xFFF1F8FD), Color(0xFFFAFCFE)],
                ),
                borderColor: const Color(0xFFCAE3F5),
                shadowColor: const Color(0xFFB0D5EE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityValue(
                value: '${activity.questionsAnswered}',
                label: 'Soal dijawab',
                icon: Icons.check_circle_outline_rounded,
                accent: const Color(0xFF32AE7C),
                bgGradient: const LinearGradient(
                  colors: <Color>[Color(0xFFF1FAF5), Color(0xFFFAFCFA)],
                ),
                borderColor: const Color(0xFFCAECDA),
                shadowColor: const Color(0xFFAEE0C4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActivityValue(
                value: '${activity.sessionCount}',
                label: 'Sesi latihan',
                icon: Icons.sports_esports_outlined,
                accent: const Color(0xFF8057D8),
                bgGradient: const LinearGradient(
                  colors: <Color>[Color(0xFFF7F3FE), Color(0xFFFAFAFE)],
                ),
                borderColor: const Color(0xFFDFD8FB),
                shadowColor: const Color(0xFFCCC2F5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityValue(
                value: activity.activeLearningMinutes == null
                    ? '—'
                    : activity.activeLearningMinutes!.toStringAsFixed(1),
                label: 'Menit terukur',
                icon: Icons.timer_outlined,
                accent: const Color(0xFFDD882E),
                bgGradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFFF9F0), Color(0xFFFFFDF8)],
                ),
                borderColor: const Color(0xFFFEDDB9),
                shadowColor: const Color(0xFFF7C89B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFF8E7), Color(0xFFFFFDF8)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE5A3), width: 1.3),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0xFFF3D27E), offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.fireGold,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.3),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0xFFD48B00), offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${activity.streak.current} hari streak aktif · rekor terbaik ${activity.streak.best} hari',
                  style: const TextStyle(
                    color: Color(0xFF8B460E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (activity.dailyHistory.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _DailyConsistencyMatrix(dailyHistory: activity.dailyHistory),
        ],
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

class _DailyConsistencyMatrix extends StatelessWidget {
  const _DailyConsistencyMatrix({required this.dailyHistory});
  final List<LearningActivityDay> dailyHistory;

  @override
  Widget build(BuildContext context) {
    if (dailyHistory.isEmpty) return const SizedBox.shrink();

    final List<LearningActivityDay> days = dailyHistory.length > 30
        ? dailyHistory.sublist(dailyHistory.length - 30)
        : dailyHistory;

    final int activeDays = days.where((d) => d.questionsAnswered > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Aktivitas 30 hari terakhir',
              style: TextStyle(
                color: AppColors.textStrong,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$activeDays hari aktif',
              style: const TextStyle(
                color: AppColors.levelUpTeal,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const int columns = 10;
            const double gap = 5;
            final double boxSize =
                (constraints.maxWidth - (columns - 1) * gap) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: days
                  .map((LearningActivityDay day) {
                    final bool isActive = day.questionsAnswered > 0;
                    final String dayLabel = day.date != null
                        ? '${day.date!.day}'
                        : '';
                    return Tooltip(
                      message: day.date == null
                          ? '${day.questionsAnswered} soal'
                          : '${_date(day.date!)}: ${day.questionsAnswered} soal (${day.sessionCount} sesi)',
                      child: Container(
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2CB88F)
                              : const Color(0xFFEFF4F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF7DE6C3)
                                : const Color(0xFFDFE6EF),
                            width: 1.2,
                          ),
                          boxShadow: isActive
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0xFF1F9E79),
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF8898AA),
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F0F8),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFD3E0EA)),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Istirahat',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9),
            ),
            const SizedBox(width: 10),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.levelUpTeal,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Latihan',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityValue extends StatelessWidget {
  const _ActivityValue({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.bgGradient,
    required this.borderColor,
    required this.shadowColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final Gradient bgGradient;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      gradient: bgGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1.4),
      boxShadow: <BoxShadow>[
        BoxShadow(color: shadowColor, offset: const Offset(0, 4)),
        const BoxShadow(
          color: Color(0x1000215A),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF142B55), Color(0xFF071A3D)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF34527F)),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0xFF030E24), offset: Offset(0, 7)),
        BoxShadow(
          color: Color(0x2600215A),
          blurRadius: 16,
          offset: Offset(0, 9),
        ),
      ],
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
                    '${competition.matchRecord.wins}M ${competition.matchRecord.losses}K ${competition.matchRecord.draws}S · ${_percent(competition.accuracy.value)} (${competition.accuracy.correctCount}/${competition.accuracy.attemptCount}) · bukti ${_evidenceStrength(competition.accuracy.confidence)}',
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _LearningClay.mint.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0xFFA9D7CE), offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: AppColors.levelUpTeal),
        ),
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

BoxDecoration _clayDecoration({Color? tint}) => BoxDecoration(
  color: tint ?? _LearningClay.paper,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: Colors.white, width: 1.5),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: _LearningClay.clayShadow, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1200215A), blurRadius: 15, offset: Offset(0, 8)),
  ],
);

final BoxDecoration _panelDecoration = _clayDecoration();

(IconData, Color) _sectionVisual(String label) => switch (label) {
  'Ringkasan kemajuan' => (
    Icons.dashboard_customize_rounded,
    _LearningClay.cyan,
  ),
  'Temuan utama' => (Icons.lightbulb_rounded, _LearningClay.peach),
  'Peta skill' => (Icons.hub_rounded, _LearningClay.lavender),
  'Retensi' => (Icons.event_repeat_rounded, _LearningClay.mint),
  'Konsistensi 30 hari' => (
    Icons.local_fire_department_rounded,
    _LearningClay.peach,
  ),
  'Assessment' => (Icons.fact_check_rounded, _LearningClay.cyan),
  'Competition' => (Icons.sports_kabaddi_rounded, _LearningClay.lavender),
  _ => (Icons.auto_awesome_rounded, _LearningClay.cyan),
};

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
