import 'package:flutter/widgets.dart';
import 'package:yudha_mobile/shared/widgets/feature_placeholder_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Profile',
      description:
          'Statistik personal, winrate, dan pengaturan akun ada di sini.',
    );
  }
}
