import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PracticeState state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);

    final profileSettings = ref.watch(profileSettingsProvider);
    final bool isCpns = profileSettings.target == ProfileTarget.cpns || profileSettings.target == null;

    void openQuiz() async {
      if (state.topics.isNotEmpty) {
        await controller.selectTopic(state.topics.first.id);
      }
      if (context.mounted) {
        context.push(AppRoutes.practiceQuiz);
      }
    }

    void openDailyChallenge() async {
      controller.startQuestionOfDay();
      context.push(AppRoutes.practiceQuiz);
    }

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        title: Text(
          'LATIHAN',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
      body: state.status == PracticeViewStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.reload,
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _HeroChallengeCard(
                            isCpns: isCpns,
                            question: state.questionOfDay?.prompt ??
                                'Memuat tantangan hari ini...',
                            tags: state.questionOfDay?.topicName ??
                                (isCpns ? 'TIU • Numerik' : 'Kepribadian • Integritas'),
                            onStart: openDailyChallenge,
                          ),
                          const SizedBox(height: 24),
                          _OverallProgress(
                            label: isCpns ? 'Progress CPNS' : 'Progress BUMN',
                            progressPercent: isCpns ? 28 : 52,
                            color: isCpns
                                ? AppColors.warriorNavy
                                : AppColors.levelUpTeal,
                          ),
                          const SizedBox(height: 24),
                          if (isCpns)
                            _CpnsGrids(onTapTopic: openQuiz)
                          else
                            _BumnGrids(onTapTopic: openQuiz),
                          const SizedBox(height: 24),
                          const Text(
                            'TERAKHIR DIKERJAKAN',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RecentActivityTile(
                            icon: Icons.article_outlined,
                            title: isCpns ? 'TWK — Pancasila' : 'Verbal — Analogi',
                            subtitle: '15 soal  ·  2 hari lalu',
                            score: '80%',
                            scoreColor: AppColors.levelUpTeal,
                          ),
                          const SizedBox(height: 8),
                          _RecentActivityTile(
                            icon: Icons.lightbulb_outline,
                            title: isCpns ? 'TIU — Numerik' : 'Interview — Motivasi',
                            subtitle:
                                isCpns ? '20 soal  ·  3 hari lalu' : '5 pertanyaan  ·  2 hari lalu',
                            score: isCpns ? '65%' : 'Selesai',
                            scoreColor: isCpns
                                ? AppColors.fireGold
                                : AppColors.warriorNavy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeroChallengeCard extends StatelessWidget {
  const _HeroChallengeCard({
    required this.isCpns,
    required this.question,
    required this.tags,
    required this.onStart,
  });

  final bool isCpns;
  final String question;
  final String tags;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCpns ? AppColors.warriorNavy : AppColors.levelUpTeal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isCpns ? AppColors.warriorNavy : AppColors.levelUpTeal)
                .withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TANTANGAN HARIAN',
            style: GoogleFonts.orbitron(
              color: Colors.white.withAlpha(200),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                tags,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor:
                  isCpns ? AppColors.warriorNavy : AppColors.levelUpTeal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text(
              'Mulai Tantangan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
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

class _CpnsGrids extends StatelessWidget {
  const _CpnsGrids({required this.onTapTopic});
  final VoidCallback onTapTopic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CategorySection(
          title: 'TWK — WAWASAN KEBANGSAAN',
          items: <_GridItemData>[
            _GridItemData('TWK', 'Pancasila', 'Nilai & implementasi', '30'),
            _GridItemData('TWK', 'UUD 1945', 'Pasal & amandemen', '25'),
            _GridItemData('TWK', 'NKRI', 'Sejarah & wawasan', '20'),
            _GridItemData('TWK', 'Bhinneka T.I.', 'Keberagaman', '30'),
          ],
          onTap: onTapTopic,
        ),
        const SizedBox(height: 24),
        _CategorySection(
          title: 'TIU — INTELEGENSIA UMUM',
          items: <_GridItemData>[
            _GridItemData('TIU', 'Verbal', 'Analogi & silogisme', '40'),
            _GridItemData('TIU', 'Numerik', 'Deret & aritmatika', '40'),
            _GridItemData('TIU', 'Figural', 'Pola & rotasi', '20'),
            _GridItemData('TIU', 'Logika', 'Deduktif & induktif', '35'),
          ],
          onTap: onTapTopic,
        ),
        const SizedBox(height: 24),
        _CategorySection(
          title: 'TKP — KARAKTERISTIK PRIBADI',
          items: <_GridItemData>[
            _GridItemData('TKP', 'Pelayanan Publik', 'Etika & integritas', '35'),
            _GridItemData('TKP', 'Sosial Budaya', 'Adaptasi & toleransi', '30'),
            _GridItemData('TKP', 'Teknologi', 'Digital & inovasi', '25'),
            _GridItemData('TKP', 'Profesionalisme', 'Etos & disiplin', '30'),
          ],
          onTap: onTapTopic,
        ),
      ],
    );
  }
}

class _BumnGrids extends StatelessWidget {
  const _BumnGrids({required this.onTapTopic});
  final VoidCallback onTapTopic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _CategorySection(
          title: 'SOAL KEMAMPUAN',
          items: <_GridItemData>[
            _GridItemData('Verbal', 'Verbal', 'Analogi & sinonim', '30'),
            _GridItemData('Numerik', 'Numerik', 'Dasar & hitung', '25'),
            _GridItemData('Logika', 'Logika', 'Penalaran & pola', '30'),
            _GridItemData('Keprib.', 'Kepribadian', 'Sikap & nilai kerja', '20'),
          ],
          onTap: onTapTopic,
        ),
        const SizedBox(height: 24),
        const Text(
          'INTERVIEW PREP',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push(AppRoutes.interview),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.levelUpTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: AppColors.levelUpTeal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Simulasi Wawancara',
                        style: TextStyle(
                          color: AppColors.textStrong,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '15 skenario · BUMN',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted.withAlpha(100),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GridItemData {
  _GridItemData(this.badge, this.title, this.subtitle, this.count);
  final String badge;
  final String title;
  final String subtitle;
  final String count;
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.items, required this.onTap});

  final String title;
  final List<_GridItemData> items;
  final VoidCallback onTap;

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
            letterSpacing: 1.2,
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
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
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
                            item.badge,
                            style: GoogleFonts.orbitron(
                              color: AppColors.warriorNavy,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${item.count} soal',
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
                          item.title,
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
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.warriorNavy.withAlpha(150),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
  const _RecentActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.scoreColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String score;
  final Color scoreColor;

  @override
  Widget build(BuildContext context) {
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
                  title,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
            score,
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
