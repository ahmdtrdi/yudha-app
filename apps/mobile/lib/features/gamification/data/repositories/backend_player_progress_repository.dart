import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class PlayerProgressApiConfig {
  const PlayerProgressApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
  });

  final String baseUrl;
  final String? accessToken;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
}

class BackendPlayerProgressRepository implements PlayerProgressRepository {
  BackendPlayerProgressRepository({
    required PlayerProgressApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final PlayerProgressApiConfig _config;
  final http.Client _client;

  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async {
    if (!_config.hasAccessToken) {
      throw const PlayerProgressApiException(
        'Sesi login sudah berakhir. Silakan masuk ulang.',
      );
    }

    final Uri uri = Uri.parse('${_config.baseUrl}/lobby/summary');
    final http.Response response = await _client.get(
      uri,
      headers: <String, String>{
        'authorization': 'Bearer ${_config.accessToken}',
        'content-type': 'application/json',
      },
    );

    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
          : response.reasonPhrase ?? 'Error';
      throw PlayerProgressApiException(message);
    }

    if (decoded is! Map<String, dynamic>) {
      throw const PlayerProgressApiException(
        'Lobby summary API returned invalid JSON.',
      );
    }

    final Map<String, dynamic> payload = _asMap(decoded['data']) ?? decoded;
    final Map<String, dynamic> profile = _asMap(payload['profile']) ?? payload;
    final Map<String, dynamic> rankedStats =
        _asMap(profile['rankedStats']) ?? <String, dynamic>{};
    final Map<String, dynamic> streakMap =
        _asMap(profile['streak']) ??
        _asMap(payload['streak']) ??
        <String, dynamic>{};
    final List<Map<String, Object?>> dailyMissions =
        (payload['dailyMissions'] as List?)
            ?.map((dynamic item) => Map<String, Object?>.from(item as Map))
            .toList() ??
        const <Map<String, Object?>>[];

    final int wins = _readInt(profile['wins'] ?? rankedStats['wins']);
    final int losses = _readInt(profile['losses'] ?? rankedStats['losses']);
    final int draws = _readInt(profile['draws'] ?? rankedStats['draws']);
    final int totalMatches = _readInt(
      profile['total_matches'] ??
          payload['total_matches'] ??
          (wins + losses + draws),
    );
    final int resolvedDraws = draws > 0 || totalMatches == 0
        ? draws
        : (totalMatches - wins - losses).clamp(0, totalMatches);
    final String fullName =
        (profile['fullName'] ??
                profile['full_name'] ??
                payload['fullName'] ??
                payload['full_name'])
            ?.toString()
            .trim() ??
        '';
    final String username =
        (profile['username'] ?? payload['username'])?.toString().trim() ?? '';
    final String displayName = fullName.isNotEmpty ? fullName : username;
    final int totalPoints = _readInt(
      profile['rankPoints'] ??
          payload['rankPoints'] ??
          profile['rank_points'] ??
          payload['rank_points'],
    );
    final int currentStreak = _readInt(
      profile['streak']?['current'] ?? streakMap['current'] ?? 0,
    );

    return PlayerProgressSnapshot(
      playerId: (profile['id'] ?? payload['id'])?.toString() ?? 'you',
      displayName: displayName.isEmpty ? 'Kamu' : displayName,
      totalPoints: totalPoints,
      wins: wins,
      losses: losses,
      draws: resolvedDraws,
      streak: currentStreak,
      dailyMissions: dailyMissions,
      learningNextAction: LearningRecommendation.tryFrom(
        payload['learningNextAction'],
      ),
    );
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class PlayerProgressApiException implements Exception {
  const PlayerProgressApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
