import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';

abstract class PlayerProgressRepository {
  const PlayerProgressRepository();

  Future<PlayerProgressSnapshot> fetchCurrentProgress();

  Future<void> acknowledgeBetaWelcome() => Future<void>.error(
    UnsupportedError('Beta welcome acknowledgment unavailable'),
  );
}
