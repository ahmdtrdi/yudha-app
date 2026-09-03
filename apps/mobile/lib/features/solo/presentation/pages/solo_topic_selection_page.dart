import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_launch_request.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_providers.dart';

class SoloTopicSelectionPage extends ConsumerWidget {
  const SoloTopicSelectionPage({super.key, this.launchRequest});

  final PracticeLaunchRequest? launchRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (launchRequest != null) {
      return PracticePage(launchRequest: launchRequest);
    }
    return PracticePage(
      onTopicSelected: (PracticeTopic topic) {
        ref.read(soloSetupControllerProvider.notifier).selectLegacyTopic(topic);
        context.pushReplacement(AppRoutes.soloLoadout);
      },
    );
  }
}
