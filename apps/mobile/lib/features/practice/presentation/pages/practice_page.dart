import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/core/theme/app_typography.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_launch_request.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/widgets/practice_activity_tile.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

abstract final class _PracticeColors {
  static const Color cyan = Color(0xFFE0F6FB);
  static const Color lime = Color(0xFFEBF8DA);
  static const Color orange = Color(0xFFFDE9D6);
}

enum _PracticeCategoryTone { cyan, lime, orange }

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key, this.focusCategory, this.launchRequest});

  final String? focusCategory;
  final PracticeLaunchRequest? launchRequest;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  bool _focusLaunchHandled = false;
  bool _focusLaunchScheduled = false;

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusCategory != widget.focusCategory ||
        oldWidget.launchRequest != widget.launchRequest) {
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
    final List<_PracticeCategoryGroup> categoryGroups = _buildCategoryGroups(
      state.topics,
      isCpns: isCpns,
    );
    final List<PracticeRecentActivity> recentActivities = state.recentActivities
        .take(3)
        .toList(growable: false);
    _scheduleFocusedPractice(state);

    Future<void> openQuiz(PracticeTopic topic) async {
      final bool started = await controller.startTopic(topic);
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
        backgroundColor: const Color(0xFF0D49B5),
        elevation: 0,
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
                child: _PracticeProgressHero(
                  targetLabel: isCpns ? 'CPNS' : 'BUMN',
                  progressPercent: state.overallProgressPercent,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _InterviewPracticeCard(
                        config: interviewConfig,
                        onTap: openInterviewPractice,
                      ),
                      const SizedBox(height: 24),
                      _PracticeTaxonomySection(
                        title: isCpns
                            ? 'LATIHAN SOAL CPNS'
                            : 'LATIHAN SOAL BUMN',
                        groups: categoryGroups,
                        onTapTopic: openQuiz,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'TERAKHIR DIKERJAKAN',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (recentActivities.isNotEmpty)
                            SizedBox(
                              height: 44,
                              child: TextButton(
                                onPressed: () =>
                                    context.push(AppRoutes.practiceHistory),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.warriorNavy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Lihat semua'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recentActivities.isEmpty)
                        Container(
                          key: const ValueKey<String>('practice-history-empty'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7E9ED)),
                          ),
                          child: const Text(
                            'Belum ada latihan yang dikerjakan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      for (
                        int index = 0;
                        index < recentActivities.length;
                        index++
                      ) ...<Widget>[
                        PracticeActivityTile(activity: recentActivities[index]),
                        if (index != recentActivities.length - 1)
                          const SizedBox(height: 8),
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

  List<_PracticeCategoryGroup> _buildCategoryGroups(
    List<PracticeTopic> sourceTopics, {
    required bool isCpns,
  }) {
    final List<_PracticeCategorySpec> specs = isCpns
        ? _PracticeCategorySpec.cpns
        : _PracticeCategorySpec.bumn;

    return specs
        .map((_PracticeCategorySpec spec) {
          final List<PracticeTopic> topics = sourceTopics
              .where(
                (PracticeTopic topic) =>
                    _identifierKey(topic.category) == spec.category,
              )
              .toList(growable: false);
          topics.sort(
            (PracticeTopic first, PracticeTopic second) => spec
                .orderOf(first.subcategory ?? first.name)
                .compareTo(spec.orderOf(second.subcategory ?? second.name)),
          );
          return _PracticeCategoryGroup(spec: spec, topics: topics);
        })
        .where((_PracticeCategoryGroup group) => group.topics.isNotEmpty)
        .toList(growable: false);
  }

  void _scheduleFocusedPractice(PracticeState state) {
    final String focusCategory =
        widget.launchRequest?.focus.trim() ??
        widget.focusCategory?.trim() ??
        '';
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
          .startRecommendedSession(
            focusCategory,
            recommendationId: widget.launchRequest?.recommendationId,
          );
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

class _PracticeProgressHero extends StatelessWidget {
  const _PracticeProgressHero({
    required this.targetLabel,
    required this.progressPercent,
  });

  final String targetLabel;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final double progress = (progressPercent / 100).clamp(0, 1).toDouble();

    return ColoredBox(
      color: AppColors.scholarCream,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey<String>('practice-progress-clay-base'),
              decoration: const BoxDecoration(
                color: Color(0xFF06378F),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
            ),
          ),
          Container(
            key: const ValueKey<String>('practice-progress-surface'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D49B5),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Flexible(
                                child: Text(
                                  'Progress latihan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                key: const ValueKey<String>(
                                  'practice-target-badge',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  targetLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Lanjutkan satu sesi untuk menjaga ritmemu',
                            style: TextStyle(
                              color: Color(0xFFC7D9FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: AppColors.fireGold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    key: const ValueKey<String>('practice-progress-bar'),
                    value: progress,
                    backgroundColor: const Color(0xFF07368D),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.fireGold,
                    ),
                    minHeight: 8,
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

class _InterviewPracticeCard extends StatelessWidget {
  const _InterviewPracticeCard({required this.config, required this.onTap});

  final InterviewLaunchConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: 7,
              child: DecoratedBox(
                key: const ValueKey<String>('practice-interview-clay-base'),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DC),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            Container(
              key: const ValueKey<String>('practice-interview-surface'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE7E9ED)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F6FB),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.record_voice_over_rounded,
                      color: Color(0xFF087C9E),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Simulasi Wawancara AI',
                          style: GoogleFonts.fredoka(
                            color: AppColors.warriorNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${config.companyName} - ${config.targetRole}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.warriorNavy,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCategorySpec {
  const _PracticeCategorySpec({
    required this.category,
    required this.tone,
    required this.subcategoryOrder,
  });

  final String category;
  final _PracticeCategoryTone tone;
  final List<String> subcategoryOrder;

  int orderOf(String value) {
    final String key = _identifierKey(value);
    final int index = subcategoryOrder.indexOf(key);
    return index < 0 ? subcategoryOrder.length : index;
  }

  static const List<_PracticeCategorySpec> cpns = <_PracticeCategorySpec>[
    _PracticeCategorySpec(
      category: 'twk',
      tone: _PracticeCategoryTone.orange,
      subcategoryOrder: <String>[
        'pancasila_dan_ideologi',
        'konstitusi_dan_negara',
        'sejarah_dan_kebangsaan',
        'bhinneka_tunggal_ika',
      ],
    ),
    _PracticeCategorySpec(
      category: 'tiu',
      tone: _PracticeCategoryTone.cyan,
      subcategoryOrder: <String>['verbal', 'numerik', 'logis', 'figural'],
    ),
    _PracticeCategorySpec(
      category: 'tkp',
      tone: _PracticeCategoryTone.lime,
      subcategoryOrder: <String>[
        'pelayanan_dan_integritas',
        'kerja_sama_dan_komunikasi',
        'adaptasi_dan_pengembangan_diri',
        'pengambilan_keputusan_dan_kinerja',
      ],
    ),
  ];

  static const List<_PracticeCategorySpec> bumn = <_PracticeCategorySpec>[
    _PracticeCategorySpec(
      category: 'tkd',
      tone: _PracticeCategoryTone.cyan,
      subcategoryOrder: <String>['verbal', 'numerik', 'logis', 'figural'],
    ),
    _PracticeCategorySpec(
      category: 'akhlak',
      tone: _PracticeCategoryTone.lime,
      subcategoryOrder: <String>['amanah', 'kompeten', 'harmonis', 'loyal'],
    ),
    _PracticeCategorySpec(
      category: 'wawasan_kebangsaan',
      tone: _PracticeCategoryTone.orange,
      subcategoryOrder: <String>[
        'pancasila',
        'uud_1945',
        'nkri',
        'bhinneka_tunggal_ika',
      ],
    ),
  ];
}

class _PracticeCategoryGroup {
  const _PracticeCategoryGroup({required this.spec, required this.topics});

  final _PracticeCategorySpec spec;
  final List<PracticeTopic> topics;

  String get title => _displayIdentifier(topics.first.category).toUpperCase();

  _TopicPalette get palette => _TopicPalette.forTone(spec.tone);
}

class _PracticeTaxonomySection extends StatelessWidget {
  const _PracticeTaxonomySection({
    required this.title,
    required this.groups,
    required this.onTapTopic,
  });

  final String title;
  final List<_PracticeCategoryGroup> groups;
  final ValueChanged<PracticeTopic> onTapTopic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.heading(
            color: AppColors.warriorNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        for (int index = 0; index < groups.length; index++) ...<Widget>[
          _PracticeCategorySection(
            group: groups[index],
            onTapTopic: onTapTopic,
          ),
          if (index < groups.length - 1) const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _PracticeCategorySection extends StatelessWidget {
  const _PracticeCategorySection({
    required this.group,
    required this.onTapTopic,
  });

  final _PracticeCategoryGroup group;
  final ValueChanged<PracticeTopic> onTapTopic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          group.title,
          style: AppTypography.heading(
            color: group.palette.foregroundColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${group.topics.length} subkategori \u2022 5 soal per sesi',
          style: AppTypography.body(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 11),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 96,
          ),
          itemCount: group.topics.length,
          itemBuilder: (BuildContext context, int index) {
            final PracticeTopic item = group.topics[index];
            return _PracticeTopicCard(
              key: ValueKey<String>('practice-topic-${item.id}'),
              topic: item,
              palette: group.palette,
              onTap: () => onTapTopic(item),
            );
          },
        ),
      ],
    );
  }
}

class _PracticeTopicCard extends StatefulWidget {
  const _PracticeTopicCard({
    super.key,
    required this.topic,
    required this.palette,
    required this.onTap,
  });

  final PracticeTopic topic;
  final _TopicPalette palette;
  final VoidCallback onTap;

  @override
  State<_PracticeTopicCard> createState() => _PracticeTopicCardState();
}

class _PracticeTopicCardState extends State<_PracticeTopicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final _TopicVisual visual = _TopicVisual.forTopic(
      widget.topic,
      widget.palette,
    );

    return Semantics(
      button: true,
      label: '${widget.topic.name}. 5 soal per sesi.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: visual.baseColor,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              top: _isPressed ? 5 : 0,
              right: 0,
              bottom: _isPressed ? 2 : 7,
              left: 0,
              child: DecoratedBox(
                key: ValueKey<String>(
                  'practice-topic-surface-${widget.topic.id}',
                ),
                decoration: BoxDecoration(
                  color: visual.frontColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: visual.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: visual.iconColor,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          visual.icon,
                          color: visual.foregroundColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.topic.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading(
                                color: visual.foregroundColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
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
      ),
    );
  }
}

class _TopicVisual {
  const _TopicVisual({
    required this.icon,
    required this.frontColor,
    required this.baseColor,
    required this.borderColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color frontColor;
  final Color baseColor;
  final Color borderColor;
  final Color iconColor;

  Color get foregroundColor {
    if (frontColor == _PracticeColors.cyan) return const Color(0xFF246F7B);
    if (frontColor == _PracticeColors.lime) return const Color(0xFF4D702C);
    if (frontColor == _PracticeColors.orange) return const Color(0xFF87512D);
    return const Color(0xFF86506F);
  }

  factory _TopicVisual.forTopic(PracticeTopic topic, _TopicPalette palette) {
    return _TopicVisual(
      icon: _iconForTopic(topic),
      frontColor: palette.frontColor,
      baseColor: palette.baseColor,
      borderColor: palette.borderColor,
      iconColor: palette.iconColor,
    );
  }

  static IconData _iconForTopic(PracticeTopic topic) {
    final String value = '${topic.name} ${topic.subcategory ?? ''}'
        .toLowerCase();
    if (value.contains('numer')) return Icons.calculate_rounded;
    if (value.contains('verbal')) return Icons.forum_rounded;
    if (value.contains('logika') || value.contains('logis')) {
      return Icons.extension_rounded;
    }
    if (value.contains('figural')) return Icons.category_rounded;
    if (value.contains('pancasila') || value.contains('ideologi')) {
      return Icons.account_balance_rounded;
    }
    if (value.contains('konstitusi') || value.contains('uud')) {
      return Icons.gavel_rounded;
    }
    if (value.contains('sejarah') || value.contains('nkri')) {
      return Icons.flag_rounded;
    }
    if (value.contains('bhinneka') || value.contains('harmonis')) {
      return Icons.diversity_3_rounded;
    }
    if (value.contains('amanah') || value.contains('integritas')) {
      return Icons.verified_user_rounded;
    }
    if (value.contains('kompeten') || value.contains('pengembangan')) {
      return Icons.school_rounded;
    }
    if (value.contains('loyal')) return Icons.favorite_rounded;
    if (value.contains('pelayanan')) return Icons.volunteer_activism_rounded;
    if (value.contains('kerja sama') || value.contains('komunikasi')) {
      return Icons.groups_rounded;
    }
    if (value.contains('keputusan') || value.contains('kinerja')) {
      return Icons.task_alt_rounded;
    }
    return Icons.shield_rounded;
  }
}

class _TopicPalette {
  const _TopicPalette({
    required this.frontColor,
    required this.baseColor,
    required this.borderColor,
    required this.iconColor,
  });

  final Color frontColor;
  final Color baseColor;
  final Color borderColor;
  final Color iconColor;

  Color get foregroundColor {
    if (frontColor == _PracticeColors.cyan) return const Color(0xFF246F7B);
    if (frontColor == _PracticeColors.lime) return const Color(0xFF4D702C);
    return const Color(0xFF87512D);
  }

  factory _TopicPalette.forTone(_PracticeCategoryTone tone) {
    return switch (tone) {
      _PracticeCategoryTone.cyan => const _TopicPalette(
        frontColor: _PracticeColors.cyan,
        baseColor: Color(0xFF83C4CF),
        borderColor: Color(0xFFB9E2E9),
        iconColor: Color(0xFFBDEAF1),
      ),
      _PracticeCategoryTone.lime => const _TopicPalette(
        frontColor: _PracticeColors.lime,
        baseColor: Color(0xFF9DC678),
        borderColor: Color(0xFFCFE5B9),
        iconColor: Color(0xFFD6EDBE),
      ),
      _PracticeCategoryTone.orange => const _TopicPalette(
        frontColor: _PracticeColors.orange,
        baseColor: Color(0xFFDDA476),
        borderColor: Color(0xFFEEC9A9),
        iconColor: Color(0xFFF5CCAA),
      ),
    };
  }
}

String _identifierKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _displayIdentifier(String value) {
  const Set<String> acronyms = <String>{
    'akhlak',
    'bumn',
    'cpns',
    'tkd',
    'tiu',
    'tkp',
    'twk',
    'nkri',
    'uud',
  };
  return value
      .trim()
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lowercase = part.toLowerCase();
        if (acronyms.contains(lowercase)) return lowercase.toUpperCase();
        return '${lowercase[0].toUpperCase()}${lowercase.substring(1)}';
      })
      .join(' ');
}
