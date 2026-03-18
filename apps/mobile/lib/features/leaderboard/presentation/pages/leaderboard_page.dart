import 'package:flutter/widgets.dart';
import 'package:yudha_mobile/shared/widgets/feature_placeholder_page.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Leaderboard',
      description: 'Peringkat pemain akan ditampilkan di sini.',
    );
  }
}
