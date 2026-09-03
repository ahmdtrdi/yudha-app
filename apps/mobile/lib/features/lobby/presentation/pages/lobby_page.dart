import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key});

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  String? _shownRecommendationId;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(playerProgressProvider);
    final LearningRecommendation? learningNextAction =
        progress.learningNextAction;
    _recordShown(learningNextAction);
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
    final List<Map<String, Object?>> dailyMissions = progress.dailyMissions;
    final Map<String, Object?> practiceMission = dailyMissions.firstWhere(
      (Map<String, Object?> mission) => mission['key'] == 'daily_practice',
      orElse: () => const <String, Object?>{
        'key': 'daily_practice',
        'title': 'Daily Question',
        'rewardYCoins': 2,
        'completed': false,
      },
    );
    final Map<String, Object?> pvpMission = dailyMissions.firstWhere(
      (Map<String, Object?> mission) => mission['key'] == 'daily_pvp',
      orElse: () => const <String, Object?>{
        'key': 'daily_pvp',
        'title': 'Daily PvP',
        'rewardYCoins': 1,
        'completed': false,
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D49B5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D49B5),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'YUDHA',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          Center(
            child: YCoinBalanceChip(
              balance: economy.isAuthoritative ? economy.yCoins : null,
              onTap: economy.isAuthoritative
                  ? () => showYCoinTopUpSheet(context)
                  : null,
              dark: true,
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.hiredPass),
            tooltip: 'Hired Pass',
            icon: const Icon(Icons.workspace_premium_rounded),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.store),
            tooltip: 'Store',
            icon: const Icon(Icons.storefront_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 720;
            final double profileHeight = constraints.maxHeight * 0.4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: profileHeight,
                  child: ColoredBox(
                    color: AppColors.scholarCream,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        DecoratedBox(
                          key: const ValueKey<String>(
                            'lobby-profile-clay-base',
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF06378F),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(26),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            key: const ValueKey<String>('lobby-profile-clip'),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(26),
                            ),
                            child: ColoredBox(
                              key: const ValueKey<String>(
                                'lobby-profile-background',
                              ),
                              color: const Color(0xFF0D49B5),
                              child: _LobbyProfileHeader(
                                compact: compact,
                                displayName: progress.displayName,
                                winRate: progress.winRate,
                                streak: progress.streak,
                                matches: progress.matchesPlayed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    key: const ValueKey<String>('lobby-mission-background'),
                    color: AppColors.scholarCream,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 20 : 24,
                        vertical: compact ? 12 : 18,
                      ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              return SingleChildScrollView(
                                key: const ValueKey<String>(
                                  'lobby-mission-scroll-view',
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      if (learningNextAction !=
                                          null) ...<Widget>[
                                        _LobbyLearningCard(
                                          recommendation: learningNextAction,
                                          compact: compact,
                                          onDashboard: () =>
                                              context.go(AppRoutes.analytics),
                                          onStart: learningNextAction.runnable
                                              ? () => _startRecommendation(
                                                  learningNextAction,
                                                )
                                              : null,
                                        ),
                                        SizedBox(height: compact ? 12 : 16),
                                      ],
                                      _QuestRoadmapSheet(
                                        compact: compact,
                                        practiceMission: practiceMission,
                                        pvpMission: pvpMission,
                                        onPracticeTap: () =>
                                            context.go(AppRoutes.solo),
                                        onPvpTap: () =>
                                            context.go(AppRoutes.pvp),
                                        onBattleTap: () =>
                                            context.go(AppRoutes.pvp),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
    context.go(AppRoutes.solo);
    // TODO: Solo setup doesn't accept a focus/recommendationId deep link
    // yet. Wire recommendation.subcategory/category + recommendation.id
    // through once SoloSetupPage supports a launch request, so "Mulai"
    // starts the recommended topic directly instead of landing on generic
    // setup.
  }
}

class _LobbyLearningCard extends StatelessWidget {
  const _LobbyLearningCard({
    required this.recommendation,
    required this.compact,
    required this.onDashboard,
    required this.onStart,
  });

  final LearningRecommendation recommendation;
  final bool compact;
  final VoidCallback onDashboard;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Rekomendasi belajar ${recommendation.skillLabel}, kekuatan bukti ${recommendation.confidence}',
      child: Container(
        key: const ValueKey<String>('lobby-learning-recommendation'),
        padding: EdgeInsets.all(compact ? 13 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFB7D0FF)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 38 : 44,
              height: compact ? 38 : 44,
              decoration: const BoxDecoration(
                color: Color(0xFF0D49B5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recommendation.objectiveLabel,
                    style: const TextStyle(
                      color: AppColors.warriorNavy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recommendation.skillLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${recommendation.compatibilityLabel ?? 'Mekanik ${recommendation.mechanicMode}'} · kekuatan bukti ${_lobbyConfidence(recommendation.confidence)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Lihat dashboard Learning',
              onPressed: onDashboard,
              icon: const Icon(Icons.insights_rounded),
            ),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Mulai'),
            ),
          ],
        ),
      ),
    );
  }
}

String _lobbyConfidence(String value) => switch (value) {
  'high' => 'tinggi',
  'medium' => 'sedang',
  _ => 'rendah',
};

class _LobbyProfileHeader extends StatelessWidget {
  const _LobbyProfileHeader({
    required this.compact,
    required this.displayName,
    required this.winRate,
    required this.streak,
    required this.matches,
  });

  final bool compact;
  final String displayName;
  final double winRate;
  final int streak;
  final int matches;

  @override
  Widget build(BuildContext context) {
    final String winRateLabel = '${(winRate * 100).toStringAsFixed(0)}%';
    return Stack(
      key: const ValueKey<String>('lobby-profile-header'),
      children: <Widget>[
        Positioned(
          top: compact ? -42 : -48,
          right: compact ? -22 : -16,
          child: Opacity(
            opacity: 0.11,
            child: SvgPicture.asset(
              'assets/icons/lobby_swords_watermark.svg',
              key: const ValueKey<String>('lobby-swords-watermark'),
              width: compact ? 170 : 210,
            ),
          ),
        ),
        Positioned(
          bottom: -116,
          left: -88,
          child: _HeroBackdropOrb(diameter: compact ? 190 : 230),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 24 : 28,
              0,
              compact ? 24 : 28,
              compact ? 16 : 22,
            ),
            child: Center(
              child: Column(
                key: const ValueKey<String>('lobby-profile-content'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeroIdentity(
                    compact: compact,
                    displayName: displayName,
                  ),
                  SizedBox(height: compact ? 26 : 32),
                  _HeroStatsPanel(
                    compact: compact,
                    winRate: winRateLabel,
                    streak: '$streak',
                    matches: '$matches',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroIdentity extends StatelessWidget {
  const _HeroIdentity({
    required this.compact,
    required this.displayName,
  });

  final bool compact;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('lobby-hero-identity'),
      children: <Widget>[
        _HeroAvatar(compact: compact),
        SizedBox(width: compact ? 12 : 15),
        Expanded(
          child: Container(
            key: const ValueKey<String>('lobby-profile-identity-panel'),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBackdropOrb extends StatelessWidget {
  const _HeroBackdropOrb({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(5),
        border: Border.all(color: Colors.white.withAlpha(9), width: 2),
      ),
    );
  }
}

class _HeroStatsPanel extends StatelessWidget {
  const _HeroStatsPanel({
    required this.compact,
    required this.winRate,
    required this.streak,
    required this.matches,
  });

  final bool compact;
  final String winRate;
  final String streak;
  final String matches;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('lobby-hero-stats-panel'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                matches,
                key: const ValueKey<String>('lobby-hero-primary-matches'),
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.fireGold,
                  fontSize: compact ? 22 : 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'RANKED MATCH',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withAlpha(205),
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              winRate,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Win rate',
              style: GoogleFonts.dmSans(
                color: Colors.white.withAlpha(180),
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          width: 1,
          height: compact ? 30 : 34,
          margin: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
          color: Colors.white.withAlpha(32),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.fireGold,
                  size: compact ? 13 : 15,
                ),
                const SizedBox(width: 3),
                Text(
                  streak,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              'Streak',
              style: GoogleFonts.dmSans(
                color: Colors.white.withAlpha(180),
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 56 : 66;
    return SizedBox(
      width: size,
      height: size + 5,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 5,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF006276),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF12ACC1), AppColors.levelUpTeal],
              ),
              border: Border.all(color: const Color(0xFF57D8E7), width: 2),
            ),
            child: Icon(
              Icons.shield_rounded,
              size: compact ? 27 : 32,
              color: const Color(0xFFD9FAFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRoadmapSheet extends StatelessWidget {
  const _QuestRoadmapSheet({
    required this.compact,
    required this.practiceMission,
    required this.pvpMission,
    required this.onPracticeTap,
    required this.onPvpTap,
    required this.onBattleTap,
  });

  final bool compact;
  final Map<String, Object?>? practiceMission;
  final Map<String, Object?>? pvpMission;
  final VoidCallback onPracticeTap;
  final VoidCallback onPvpTap;
  final VoidCallback onBattleTap;

  @override
  Widget build(BuildContext context) {
    final int totalQuests = [
      practiceMission,
      pvpMission,
    ].whereType<Map<String, Object?>>().length;
    final int completedQuests = [practiceMission, pvpMission]
        .whereType<Map<String, Object?>>()
        .where((Map<String, Object?> mission) => mission['completed'] == true)
        .length;

    return Stack(
      key: const ValueKey<String>('lobby-floating-board'),
      children: <Widget>[
        Positioned.fill(
          top: 8,
          child: DecoratedBox(
            key: const ValueKey<String>('lobby-floating-board-base'),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DC),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
        Container(
          key: const ValueKey<String>('lobby-quest-roadmap'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 24,
            compact ? 18 : 22,
            compact ? 20 : 24,
            compact ? 16 : 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE7E9ED)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'MISI HARI INI',
                    style: GoogleFonts.fredoka(
                      color: AppColors.warriorNavy,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.levelUpTeal.withAlpha(24),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$completedQuests / $totalQuests',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.levelUpTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _RoadmapQuestStep(
                    stepKey: 'practice',
                    compact: compact,
                    icon: Icons.menu_book_rounded,
                    title: (practiceMission?['title'] ?? 'Daily Question')
                        .toString(),
                    subtitle: practiceMission?['completed'] == true
                        ? 'Selesai hari ini'
                        : 'Selesaikan satu sesi practice',
                    xpReward:
                        '+${((practiceMission?['rewardYCoins'] as num?) ?? 2).toInt()} YCoin',
                    completed: practiceMission?['completed'] == true,
                    onTap: onPracticeTap,
                  ),
                  _RoadmapConnector(compact: compact),
                  _RoadmapQuestStep(
                    stepKey: 'pvp',
                    compact: compact,
                    icon: Icons.sports_kabaddi_rounded,
                    title: (pvpMission?['title'] ?? 'Daily PvP').toString(),
                    subtitle: pvpMission?['completed'] == true
                        ? 'Selesai hari ini'
                        : 'Menangkan satu pertarungan',
                    xpReward:
                        '+${((pvpMission?['rewardYCoins'] as num?) ?? 1).toInt()} YCoin',
                    completed: pvpMission?['completed'] == true,
                    onTap: onPvpTap,
                  ),
                ],
              ),
              SizedBox(height: compact ? 22 : 28),
              _ClayBattleButton(compact: compact, onPressed: onBattleTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadmapQuestStep extends StatelessWidget {
  const _RoadmapQuestStep({
    required this.stepKey,
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.xpReward,
    required this.completed,
    required this.onTap,
  });

  final String stepKey;
  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;
  final String xpReward;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color nodeColor = completed
        ? AppColors.levelUpTeal
        : const Color(0xFF0066DE);

    return SizedBox(
      key: ValueKey<String>('lobby-roadmap-step-$stepKey'),
      height: compact ? 80 : 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: compact ? 60 : 68,
            height: compact ? 59 : 66,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                Positioned(
                  top: 6,
                  child: Container(
                    width: compact ? 54 : 60,
                    height: compact ? 54 : 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003C9D),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  key: ValueKey<String>('lobby-roadmap-node-$stepKey'),
                  width: compact ? 54 : 60,
                  height: compact ? 54 : 60,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : icon,
                    color: Colors.white,
                    size: compact ? 27 : 30,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  top: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DDE5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned.fill(
                  bottom: 5,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: AppColors.warriorNavy.withAlpha(20),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 16,
                          vertical: compact ? 8 : 13,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.warriorNavy,
                                      fontSize: compact ? 13 : 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.textMuted,
                                      fontSize: compact ? 10.5 : 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              xpReward,
                              style: GoogleFonts.jetBrainsMono(
                                color: const Color(0xFFE9822D),
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
    );
  }
}

class _RoadmapConnector extends StatelessWidget {
  const _RoadmapConnector({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey<String>('lobby-roadmap-connector'),
        width: 4,
        height: compact ? 28 : 36,
        margin: EdgeInsets.only(left: compact ? 27 : 30),
        decoration: BoxDecoration(
          color: const Color(0xFF89BDF4),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

class _ClayBattleButton extends StatelessWidget {
  const _ClayBattleButton({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('lobby-start-battle'),
      height: compact ? 58 : 66,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 7,
            child: DecoratedBox(
              key: const ValueKey<String>('lobby-start-battle-base'),
              decoration: BoxDecoration(
                color: const Color(0xFFF2A45E),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 7,
            child: Material(
              key: const ValueKey<String>('lobby-start-battle-face'),
              color: const Color(0xFFFFD8A6),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: Text(
                    'START BATTLE',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFC96F20),
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
