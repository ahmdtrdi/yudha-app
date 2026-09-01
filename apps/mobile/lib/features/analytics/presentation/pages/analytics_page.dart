import 'package:flutter/material.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey<String>('analytics-empty-page'),
      color: AppColors.scholarCream,
      child: SizedBox.expand(),
    );
  }
}
