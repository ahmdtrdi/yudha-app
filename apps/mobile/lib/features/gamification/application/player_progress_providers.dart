import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';

final StateNotifierProvider<PlayerProgressController, PlayerProgress>
playerProgressProvider =
    StateNotifierProvider<PlayerProgressController, PlayerProgress>(
      (Ref ref) => PlayerProgressController(),
    );
