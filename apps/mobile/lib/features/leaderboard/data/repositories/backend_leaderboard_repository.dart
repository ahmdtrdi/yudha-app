import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/mock_leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_page_payload.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';

class LeaderboardApiConfig {
  const LeaderboardApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
  });

  final String baseUrl;
  final String? accessToken;
}

class BackendLeaderboardRepository extends LeaderboardRepository {
  BackendLeaderboardRepository({
    required LeaderboardApiConfig config,
    http.Client? client,
    LeaderboardRepository? fallbackRepository,
  }) : _config = config,
       _client = client ?? http.Client(),
       _fallbackRepository =
           fallbackRepository ?? const MockLeaderboardRepository();

  final LeaderboardApiConfig _config;
  final http.Client _client;
  final LeaderboardRepository _fallbackRepository;

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    try {
      final Uri uri = Uri.parse(
        '${_config.baseUrl}/leaderboard?scope=${query.scope.name}&page=${query.page}&pageSize=${query.pageSize}',
      );
      final http.Response response = await _client.get(
        uri,
        headers: <String, String>{
          'content-type': 'application/json',
          if ((_config.accessToken ?? '').trim().isNotEmpty)
            'authorization': 'Bearer ${_config.accessToken}',
        },
      );
      final Object? decoded = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LeaderboardApiException(
          decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    response.reasonPhrase ??
                    'Error'
              : response.reasonPhrase ?? 'Error',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const LeaderboardApiException(
          'Leaderboard API returned invalid JSON.',
        );
      }
      return _payloadFromJson(decoded);
    } catch (_) {
      return _fallbackRepository.fetchPage(query);
    }
  }

  LeaderboardPagePayload _payloadFromJson(Map<String, dynamic> json) {
    return LeaderboardPagePayload(
      entries: (json['entries'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_entryFromJson)
          .toList(growable: false),
      hasMore: json['hasMore'] == true,
      currentUserRank: _readNullableInt(json['currentUserRank']),
      currentUserEntry: json['currentUserEntry'] is Map<String, dynamic>
          ? _entryFromJson(json['currentUserEntry'] as Map<String, dynamic>)
          : null,
    );
  }

  LeaderboardEntry _entryFromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId']?.toString() ?? '',
      playerName: json['playerName']?.toString() ?? '',
      points: _readNullableInt(json['points']) ?? 0,
      winRate: _readDouble(json['winRate']),
      streak: _readNullableInt(json['streak']) ?? 0,
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }

  int? _readNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double _readDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class LeaderboardApiException implements Exception {
  const LeaderboardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
