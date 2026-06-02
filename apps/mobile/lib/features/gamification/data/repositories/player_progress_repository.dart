import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';

abstract class PlayerProgressRepository {
  const PlayerProgressRepository();

  Future<PlayerProgress> fetchCurrentProgress();
}
