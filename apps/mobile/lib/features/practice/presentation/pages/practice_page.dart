import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key, this.focusCategory});

  final String? focusCategory;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  bool _focusLaunchHandled = false;
  bool _focusLaunchScheduled = false;

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusCategory != widget.focusCategory) {
      _focusLaunchHandled = false;
      _focusLaunchScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PracticeState state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);
    final profileSettings = ref.watch(profileSettingsProvider);
    final bool isCpns =
        profileSettings.target == ProfileTarget.cpns ||
        profileSettings.target == null;
    final InterviewLaunchConfig interviewConfig = isCpns
        ? InterviewLaunchConfig.cpnsDefault()
        : InterviewLaunchConfig.bumnDefault();
    final Map<String, List<PracticeTopic>> topicGroups = _groupTopics(
      state.topics,
    );
    _scheduleFocusedPractice(state);

    Future<void> openQuiz(String topicId) async {
      final bool started = await controller.startSession(topicId);
      if (!context.mounted) {
        return;
      }
      if (started) {
        context.push(AppRoutes.practiceQuiz);
        return;
      }
      final String message =
          ref.read(practiceControllerProvider).errorMessage ??
          'Gagal memulai sesi latihan.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    void openInterviewPractice() {
      context.push(AppRoutes.interviewSetup);
    }

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        title: Text(
          'LATIHAN',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              child: Text(
                isCpns ? 'CPNS' : 'BUMN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (state.status) {
        PracticeViewStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PracticeViewStatus.error when state.topics.isEmpty =>
          _PracticeErrorView(
            message: state.errorMessage ?? 'Gagal memuat latihan. Coba lagi.',
            onRetry: controller.reload,
          ),
        _ => RefreshIndicator(
          onRefresh: controller.reload,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _OverallProgress(
                        label: isCpns ? 'Progress CPNS' : 'Progress BUMN',
                        progressPercent: state.overallProgressPercent,
                        color: isCpns
                            ? AppColors.warriorNavy
                            : AppColors.levelUpTeal,
                      ),
                      const SizedBox(height: 24),
                      _InterviewPracticeCard(
                        config: interviewConfig,
                        onTap: openInterviewPractice,
                      ),
                      const SizedBox(height: 24),
                      for (final MapEntry<String, List<PracticeTopic>> entry
                          in topicGroups.entries) ...<Widget>[
                        _CategorySection(
                          title: entry.key,
                          items: entry.value,
                          onTapTopic: openQuiz,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (state.recentActivities.isNotEmpty) ...<Widget>[
                        const Text(
                          'TERAKHIR DIKERJAKAN',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (
                          int index = 0;
                          index < state.recentActivities.length;
                          index++
                        ) ...<Widget>[
                          _RecentActivityTile(
                            activity: state.recentActivities[index],
                          ),
                          if (index != state.recentActivities.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }

  Map<String, List<PracticeTopic>> _groupTopics(List<PracticeTopic> topics) {
    final Map<String, List<PracticeTopic>> groups =
        <String, List<PracticeTopic>>{};
    for (final PracticeTopic topic in topics) {
      groups.putIfAbsent(topic.groupTitle, () => <PracticeTopic>[]).add(topic);
    }
    return groups;
  }

  void _scheduleFocusedPractice(PracticeState state) {
    final String focusCategory = widget.focusCategory?.trim() ?? '';
    if (_focusLaunchHandled ||
        _focusLaunchScheduled ||
        focusCategory.isEmpty ||
        state.status != PracticeViewStatus.ready ||
        state.topics.isEmpty) {
      return;
    }

    _focusLaunchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusLaunchHandled = true;
      _focusLaunchScheduled = false;
      final bool started = await ref
          .read(practiceControllerProvider.notifier)
          .startRecommendedSession(focusCategory);
      if (!mounted) {
        return;
      }
      if (started) {
        context.push(AppRoutes.practiceQuiz);
        return;
      }
      final String message =
          ref.read(practiceControllerProvider).errorMessage ??
          'Kategori latihan yang direkomendasikan belum tersedia.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }
}

class _PracticeErrorView extends StatelessWidget {
  const _PracticeErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.textMuted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warriorNavy,
              ),
              child: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({
    required this.label,
    required this.progressPercent,
    required this.color,
  });

  final String label;
  final int progressPercent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.warriorNavy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              '$progressPercent%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressPercent / 100,
            backgroundColor: AppColors.warriorNavy.withAlpha(20),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _InterviewPracticeCard extends StatelessWidget {
  const _InterviewPracticeCard({required this.config, required this.onTap});

  final InterviewLaunchConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.warriorNavy, Color(0xFF0E4AAE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.warriorNavy.withAlpha(35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(45)),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                color: AppColors.fireGold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Latihan Interview AI',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${config.companyName} - ${config.targetRole}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.items,
    required this.onTapTopic,
  });

  final String title;
  final List<PracticeTopic> items;
  final ValueChanged<String> onTapTopic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final PracticeTopic item = items[index];
            return InkWell(
              onTap: () => onTapTopic(item.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warriorNavy.withAlpha(20),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.warriorNavy.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warriorNavy.withAlpha(15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.badgeLabel ?? item.name,
                            style: GoogleFonts.dmSans(
                              color: AppColors.warriorNavy,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${item.questionCount} soal',
                          style: TextStyle(
                            color: AppColors.textMuted.withAlpha(120),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.warriorNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.warriorNavy.withAlpha(150),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.activity});

  final PracticeRecentActivity activity;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (activity.type) {
      PracticeRecentActivityType.insight => Icons.lightbulb_outline,
      PracticeRecentActivityType.interview => Icons.record_voice_over_rounded,
      PracticeRecentActivityType.quiz => Icons.article_outlined,
    };
    final Color scoreColor = switch (activity.type) {
      PracticeRecentActivityType.insight => AppColors.fireGold,
      PracticeRecentActivityType.interview => AppColors.warriorNavy,
      PracticeRecentActivityType.quiz => AppColors.levelUpTeal,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.scholarCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.warriorNavy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.title,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.scoreLabel,
            style: TextStyle(
              color: scoreColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
