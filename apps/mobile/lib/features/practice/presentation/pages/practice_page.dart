import 'package:flutter/widgets.dart';
import 'package:yudha_mobile/shared/widgets/feature_placeholder_page.dart';

class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Practice Session',
      description: 'Latihan soal, hint, dan daily challenge akan ada di sini.',
    );
  }
}
