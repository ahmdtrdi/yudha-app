import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';

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

    final Uri uri = Uri.parse('${_config.baseUrl}/profile');
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
        'Profile API returned invalid JSON.',
      );
    }

    final int wins = _readInt(decoded['wins']);
    final int losses = _readInt(decoded['losses']);
    final int totalMatches = _readInt(decoded['total_matches']);
    final int draws = (totalMatches - wins - losses).clamp(0, totalMatches);
    final String fullName = decoded['full_name']?.toString().trim() ?? '';
    final String username = decoded['username']?.toString().trim() ?? '';
    final String displayName = fullName.isNotEmpty ? fullName : username;

    return PlayerProgressSnapshot(
      playerId: decoded['id']?.toString() ?? 'you',
      displayName: displayName.isEmpty ? 'Kamu' : displayName,
      totalPoints: _readInt(decoded['rank_points']),
      wins: wins,
      losses: losses,
      draws: draws,
    );
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
