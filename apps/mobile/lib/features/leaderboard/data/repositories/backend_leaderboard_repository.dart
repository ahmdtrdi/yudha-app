import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
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
  }) : _config = config,
       _client = client ?? http.Client();

  final LeaderboardApiConfig _config;
  final http.Client _client;

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    final int limit = query.pageSize;
    final int offset = (query.page - 1) * query.pageSize;
    final Map<String, dynamic> leaderboardBody = await _get(
      '/leaderboard?limit=$limit&offset=$offset',
    );
    final LeaderboardPagePayload pagePayload = _payloadFromJson(
      leaderboardBody,
    );
    return _attachCurrentUser(pagePayload);
  }

  LeaderboardPagePayload _payloadFromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? page = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;
    final List<dynamic> items =
        page?['items'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const <dynamic>[];

    return LeaderboardPagePayload(
      entries: items
          .whereType<Map<String, dynamic>>()
          .map(_entryFromJson)
          .toList(growable: false),
      hasMore: _readHasMore(json, page: page),
    );
  }

  LeaderboardEntry _entryFromJson(Map<String, dynamic> json) {
    final String playerId =
        json['userId']?.toString() ?? json['playerId']?.toString() ?? '';
    if (playerId.trim().isEmpty) {
      throw const LeaderboardApiException(
        'Leaderboard API returned an entry without a user ID.',
      );
    }

    final String playerName =
        json['username']?.toString().trim() ??
        json['playerName']?.toString().trim() ??
        '';

    return LeaderboardEntry(
      rank: _readRequiredInt(json['rank'], field: 'rank'),
      playerId: playerId,
      playerName: playerName.isEmpty ? 'Pengguna YUDHA' : playerName,
      points: _readNullableInt(json['rankPoints'] ?? json['points']) ?? 0,
      winRate: _readRate(
        json['rankedWinRate'] ?? json['winrate'] ?? json['winRate'],
      ),
      totalMatches:
          _readNullableInt(json['totalMatches'] ?? json['total_matches']) ?? 0,
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final Uri uri = Uri.parse('${_config.baseUrl}$path');
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
            ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
            : response.reasonPhrase ?? 'Error',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const LeaderboardApiException(
        'Leaderboard API returned invalid JSON.',
      );
    }
    return decoded;
  }

  Future<LeaderboardPagePayload> _attachCurrentUser(
    LeaderboardPagePayload payload,
  ) async {
    if ((_config.accessToken ?? '').trim().isEmpty) {
      return payload;
    }

    final Map<String, dynamic> body = await _get('/leaderboard/me');
    final Map<String, dynamic>? data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : null;
    if (data == null) {
      throw const LeaderboardApiException(
        'Leaderboard API returned no current-user rank.',
      );
    }

    final LeaderboardEntry currentUserEntry = _entryFromJson(
      data,
    ).copyWith(isCurrentUser: true);
    final List<LeaderboardEntry> entries = payload.entries
        .map(
          (LeaderboardEntry entry) =>
              entry.playerId == currentUserEntry.playerId
              ? currentUserEntry
              : entry.copyWith(isCurrentUser: false),
        )
        .toList(growable: false);

    return LeaderboardPagePayload(
      entries: entries,
      hasMore: payload.hasMore,
      currentUserRank: currentUserEntry.rank,
      currentUserEntry: currentUserEntry,
    );
  }

  bool _readHasMore(Map<String, dynamic> json, {Map<String, dynamic>? page}) {
    final Object? meta = json['meta'] ?? page;
    if (meta is Map<String, dynamic>) {
      final int? total = _readNullableInt(meta['total']);
      final int? offset = _readNullableInt(meta['offset']);
      final int? limit = _readNullableInt(meta['limit']);
      if (total != null && offset != null && limit != null) {
        return offset + limit < total;
      }
    }
    final List<dynamic> data =
        json['data'] as List<dynamic>? ?? const <dynamic>[];
    final int? limit = _readNullableInt(
      json['meta'] is Map<String, dynamic>
          ? (json['meta'] as Map<String, dynamic>)['limit']
          : null,
    );
    return limit != null && data.length >= limit;
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

  int _readRequiredInt(Object? value, {required String field}) {
    final int? parsed = _readNullableInt(value);
    if (parsed == null || parsed <= 0) {
      throw LeaderboardApiException(
        'Leaderboard API returned an invalid $field.',
      );
    }
    return parsed;
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

  double _readRate(Object? value) {
    final double rate = _readDouble(value);
    return rate > 1 ? rate / 100 : rate;
  }
}

class LeaderboardApiException implements Exception {
  const LeaderboardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
