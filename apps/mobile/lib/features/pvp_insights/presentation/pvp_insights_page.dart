import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/learning/presentation/widgets/learning_explanation_sheet.dart';
import 'package:yudha_mobile/features/pvp_insights/application/pvp_insights_controller.dart';
import 'package:yudha_mobile/features/pvp_insights/application/pvp_insights_providers.dart';
import 'package:yudha_mobile/features/pvp_insights/domain/pvp_insights.dart';

class PvpInsightsPage extends ConsumerWidget {
  const PvpInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pvpInsightsControllerProvider);
    final controller = ref.read(pvpInsightsControllerProvider.notifier);
    final dashboard = state.dashboard;
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D49B5),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'PVP INSIGHTS',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: <Widget>[
          LearningInfoButton(
            color: Colors.white,
            explanation: _overviewExplanation,
          ),
        ],
      ),
      body: dashboard == null && state.loading
          ? const Center(child: CircularProgressIndicator())
          : dashboard == null
          ? _MessageState(message: state.error ?? 'Belum ada data.', onRetry: controller.load)
          : RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  if (state.loading) const LinearProgressIndicator(minHeight: 3),
                  if (state.error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(state.error!, style: const TextStyle(color: Color(0xFFB42318))),
                  ],
                  _Filters(state: state, controller: controller),
                  const SizedBox(height: 14),
                  _RatingHero(dashboard: dashboard),
                  const SizedBox(height: 14),
                  _MetricGrid(record: dashboard.publicPerformance),
                  const SizedBox(height: 20),
                  _Heading('Tren akurasi', explanation: _accuracyExplanation(dashboard)),
                  const SizedBox(height: 8),
                  _TrendCard(points: dashboard.trend),
                  const SizedBox(height: 20),
                  const _Heading('Topik kompetitif'),
                  const SizedBox(height: 8),
                  _TopicCard(dashboard: dashboard),
                  const SizedBox(height: 20),
                  const _Heading('PvP Coach'),
                  const SizedBox(height: 8),
                  _CoachCard(coach: dashboard.coach),
                  const SizedBox(height: 20),
                  const _Heading('Private'),
                  const SizedBox(height: 8),
                  _PrivateCard(record: dashboard.privatePerformance),
                  const SizedBox(height: 14),
                  Text(
                    'Bot tidak dihitung. Private tidak memengaruhi rating, rank, atau coach.',
                    style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.controller});
  final PvpInsightsState state;
  final PvpInsightsController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Wrap(
        spacing: 8,
        children: PvpInsightsWindow.values.map((value) => ChoiceChip(
          label: Text(value.label),
          selected: state.window == value,
          onSelected: (_) => controller.setWindow(value),
        )).toList(growable: false),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: PvpInsightsMode.values.map((value) => ChoiceChip(
          label: Text(value.label),
          selected: state.mode == value,
          onSelected: (_) => controller.setMode(value),
        )).toList(growable: false),
      ),
    ],
  );
}

class _RatingHero extends StatelessWidget {
  const _RatingHero({required this.dashboard});
  final PvpInsightsDashboard dashboard;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF0D49B5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.shield_rounded, color: AppColors.fireGold, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('TARGET ${dashboard.target.toUpperCase()}', style: const TextStyle(color: Color(0xFFC7D9FF), fontWeight: FontWeight.w800, fontSize: 11)),
              Text('${dashboard.rating} Elo', style: GoogleFonts.fredoka(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              Text(dashboard.ratingStatus == 'unrated' ? 'Unrated · selesaikan Ranked' : 'Peringkat #${dashboard.rank ?? '-'}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        Text(
          '${dashboard.ratingChange >= 0 ? '+' : ''}${dashboard.ratingChange}',
          style: GoogleFonts.jetBrainsMono(color: dashboard.ratingChange >= 0 ? const Color(0xFF75E0E8) : const Color(0xFFFFB4A8), fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.record});
  final PvpRecord record;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: <Widget>[
      _Metric('W–L–D', '${record.wins}–${record.losses}–${record.draws}'),
      _Metric('Win rate', _percent(record.winRate)),
      _Metric('Akurasi', _percent(record.accuracy)),
      _Metric('Timeout', _percent(record.timeoutRate)),
      _Metric('Pace median', record.medianResponseTimeMs == null ? '—' : '${(record.medianResponseTimeMs! / 1000).toStringAsFixed(1)} dtk'),
      _Metric('Jawaban', '${record.attempts}'),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(value, style: const TextStyle(color: AppColors.warriorNavy, fontWeight: FontWeight.w900, fontSize: 20)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.explanation});
  final String text;
  final LearningExplanation? explanation;

  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
    Expanded(child: Text(text.toUpperCase(), style: GoogleFonts.fredoka(color: AppColors.warriorNavy, fontWeight: FontWeight.w800, fontSize: 14))),
    if (explanation != null) LearningInfoButton(explanation: explanation!),
  ]);
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});
  final List<PvpTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final values = points.where((point) => point.accuracy != null).toList();
    if (values.isEmpty) return const _EmptyCard('Belum ada jawaban untuk membuat tren.');
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration,
      child: CustomPaint(painter: _TrendPainter(values.map((point) => point.accuracy!).toList())),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE7E9ED)..strokeWidth = 1;
    final line = Paint()..color = AppColors.levelUpTeal..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (final fraction in <double>[0, .5, 1]) {
      canvas.drawLine(Offset(0, size.height * fraction), Offset(size.width, size.height * fraction), grid);
    }
    final path = Path();
    for (var index = 0; index < values.length; index += 1) {
      final x = values.length == 1 ? size.width / 2 : index * size.width / (values.length - 1);
      final y = size.height * (1 - values[index].clamp(0, 1));
      if (index == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => oldDelegate.values != values;
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.dashboard});
  final PvpInsightsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    if (dashboard.topics.isEmpty) {
      return _EmptyCard(dashboard.broadAttempts == 0
          ? 'Belum ada jawaban PvP.'
          : 'Statistik umum tersedia, tetapi ${dashboard.broadAttempts - dashboard.enrichedAttempts} jawaban lama belum memiliki metadata topik immutable.');
    }
    return Container(
      decoration: _panelDecoration,
      child: Column(children: dashboard.topics.take(6).map((topic) => ListTile(
        title: Text(topic.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${topic.attempts} jawaban · evidence ${topic.evidenceStrength}'),
        trailing: Text(_percent(topic.accuracy), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.warriorNavy)),
      )).toList(growable: false)),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach});
  final PvpCoach? coach;

  @override
  Widget build(BuildContext context) {
    if (coach == null) return const _EmptyCard('Coach muncul setelah tersedia cukup evidence topik dalam 30 hari.');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF0D8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFFC978))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(coach!.headline, style: const TextStyle(color: AppColors.warriorNavy, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 5),
        Text(coach!.reason, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.solo, extra: <String, Object?>{'source': 'pvp_coach', 'skillId': coach!.skillId, 'category': coach!.category}),
          icon: const Icon(Icons.fitness_center_rounded),
          label: const Text('LATIHAN SOLO'),
        ),
      ]),
    );
  }
}

class _PrivateCard extends StatelessWidget {
  const _PrivateCard({required this.record});
  final PvpRecord record;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: _panelDecoration,
    child: Row(children: <Widget>[
      const Icon(Icons.lock_outline_rounded, color: AppColors.levelUpTeal),
      const SizedBox(width: 12),
      Expanded(child: Text('${record.matches} match · ${record.attempts} jawaban · akurasi ${_percent(record.accuracy)}')),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _panelDecoration,
    child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
    Text(message), const SizedBox(height: 10), FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
  ]));
}

String _percent(double? value) => value == null ? '—' : '${(value * 100).toStringAsFixed(0)}%';

final _panelDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFE7E9ED)),
);

const _overviewExplanation = LearningExplanation(
  title: 'Cara membaca PvP Insights',
  definition: 'Analitik ini mengukur performa dalam konteks kompetisi dan tidak menjadi bukti mastery Solo.',
  counts: 'Ranked dan Casual sesuai filter. Private ditampilkan terpisah.',
  doesNotCount: 'Bot, pertanyaan yang diinvalidasi, dan Private untuk rating/rank/coach.',
  formula: 'Elo dimulai dari 1000. Perubahan = round(32 × (hasil aktual − hasil yang diperkirakan)).',
  example: 'Dua pemain 1000: pemenang menjadi 1016 dan yang kalah 984.',
  evidenceWindow: 'Default 30 hari; tersedia 7 hari dan semua waktu. Batas hari memakai WIB.',
);

LearningExplanation _accuracyExplanation(PvpInsightsDashboard dashboard) => LearningExplanation(
  title: 'Akurasi, pace, dan evidence',
  definition: 'Akurasi memakai setiap encounter PvP yang valid, termasuk pertanyaan yang pernah dilihat.',
  counts: '${dashboard.publicPerformance.correct} benar dari ${dashboard.publicPerformance.attempts} jawaban publik.',
  doesNotCount: 'Bot dan jawaban yang diinvalidasi. Data lama tanpa revision tidak masuk rincian topik.',
  formula: 'Akurasi = benar ÷ jawaban. Untuk ranking coach: smoothedAccuracy = (benar + 2) ÷ (jawaban + 4), lalu repairScore = 0,7 × (1 − smoothedAccuracy) + 0,3 × timeoutRate.',
  example: 'Jika 9 benar dari 20, smoothedAccuracy = 11 ÷ 24 = 45,8%. Tambahan 2/4 adalah prior Beta(2,2) agar sampel kecil tidak terlalu ekstrem.',
  evidenceWindow: 'Coach selalu memakai Ranked + Casual selama 30 hari, terlepas dari filter halaman.',
);
