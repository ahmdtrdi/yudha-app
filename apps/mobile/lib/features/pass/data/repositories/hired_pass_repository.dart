import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';

class HiredPassRepository {
  HiredPassRepository({
    required this.accessToken,
    this.baseUrl = AppConfig.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String? accessToken;
  final String baseUrl;
  final http.Client _client;

  Future<HiredPassStatus> fetchStatus() async {
    final String token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const HiredPassApiException('Silakan masuk untuk melihat misi.');
    }

    final http.Response response = await _client.get(
      Uri.parse('$baseUrl/hired-pass'),
      headers: <String, String>{'authorization': 'Bearer $token'},
    );
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? 'Gagal memuat misi harian.'
          : 'Gagal memuat misi harian.';
      throw HiredPassApiException(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const HiredPassApiException('Data misi tidak valid.');
    }

    final Object? wrapped = decoded['data'];
    final Map<String, dynamic> data = wrapped is Map<String, dynamic>
        ? wrapped
        : decoded;
    final Object? rawMissions = data['missions'];
    final List<HiredPassMission> missions = rawMissions is List
        ? rawMissions
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> value) => HiredPassMission(
                  id: value['id']?.toString() ?? '',
                  title: value['title']?.toString() ?? '',
                  description: value['description']?.toString() ?? '',
                  cadence: value['cadence']?.toString() ?? '',
                  progress: _int(value['progress']),
                  target: _int(value['target']),
                  passPointsReward: _int(
                    value['passPointsReward'] ?? value['points'],
                  ),
                  completed: value['completed'] == true,
                ),
              )
              .toList(growable: false)
        : const <HiredPassMission>[];

    final Object? rawRewards = data['rewards'];
    final List<HiredPassReward> rewards = rawRewards is List
        ? rawRewards
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> value) => HiredPassReward(
                  id: value['id']?.toString() ?? '',
                  track: value['track']?.toString() ?? 'free',
                  pointsRequired: _int(value['pointsRequired']),
                  label: value['label']?.toString() ?? '',
                  coins: _int(value['coins'] ?? value['coinsAwarded']),
                  itemId: value['itemId']?.toString(),
                ),
              )
              .toList(growable: false)
        : const <HiredPassReward>[];
    final Map<String, dynamic> season = _map(data['season']);
    final Map<String, dynamic> entitlement = _map(data['entitlement']);

    return HiredPassStatus(
      seasonId: season['id']?.toString(),
      passPoints: _int(data['passPoints']),
      premiumActive: entitlement['premiumActive'] == true,
      expiresAt: DateTime.tryParse(entitlement['expiresAt']?.toString() ?? ''),
      missions: missions,
      rewards: rewards,
      claimedRewardIds: _list(data['claimedRewardIds'])
          .map((Object? value) => value.toString())
          .toSet(),
    );
  }

  Future<HiredPassMutationResult> activateBeta(String seasonId) async {
    final Map<String, dynamic> data = await _request(
      'POST',
      Uri.parse('$baseUrl/hired-pass/beta-activate'),
      body: <String, Object?>{
        'seasonId': seasonId,
        'idempotencyKey': _requestId('activate-$seasonId'),
      },
    );
    return HiredPassMutationResult.fromJson(data);
  }

  Future<HiredPassMutationResult> claimReward(String rewardId) async {
    final Map<String, dynamic> data = await _request(
      'POST',
      Uri.parse('$baseUrl/hired-pass/rewards/$rewardId/claim'),
      body: <String, Object?>{
        'idempotencyKey': _requestId('claim-$rewardId'),
      },
    );
    return HiredPassMutationResult.fromJson(data);
  }

  static int _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  static List<Object?> _list(Object? value) {
    return value is List<Object?> ? value : const <Object?>[];
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final String token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const HiredPassApiException('Silakan masuk untuk melanjutkan.');
    }
    final Map<String, String> headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    final http.Response response = method == 'POST'
        ? await _client.post(uri, headers: headers, body: jsonEncode(body))
        : await _client.get(uri, headers: headers);
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = _errorMessage(decoded);
      throw HiredPassApiException(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const HiredPassApiException('Data Hired Pass tidak valid.');
    }
    final Object? wrapped = decoded['data'];
    return wrapped is Map<String, dynamic> ? wrapped : decoded;
  }

  String _requestId(String operation) {
    return 'mobile-hired-pass-$operation-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _errorMessage(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return 'Aksi Hired Pass gagal.';
    }
    final Object? direct = decoded['message'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    final Object? error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final Object? nested = error['message'];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString();
      }
    }
    return 'Aksi Hired Pass gagal.';
  }

  void dispose() {
    _client.close();
  }
}

class HiredPassMutationResult {
  const HiredPassMutationResult({
    required this.success,
    required this.replayed,
    this.rewardId,
    this.coins,
    this.itemId,
    this.premiumActive = false,
    this.expiresAt,
  });

  factory HiredPassMutationResult.fromJson(Map<String, dynamic> data) {
    return HiredPassMutationResult(
      success: data['activated'] == true || data['claimed'] == true,
      replayed: data['replayed'] == true,
      rewardId: data['rewardId']?.toString(),
      coins: _intValue(data['coins'] ?? data['yCoins'] ?? data['coinsAwarded']),
      itemId: data['itemId']?.toString(),
      premiumActive: _mapValue(data['entitlement'])['premiumActive'] == true,
      expiresAt: DateTime.tryParse(
        _mapValue(data['entitlement'])['expiresAt']?.toString() ?? '',
      ),
    );
  }

  final bool success;
  final bool replayed;
  final String? rewardId;
  final int? coins;
  final String? itemId;
  final bool premiumActive;
  final DateTime? expiresAt;

  static int _intValue(Object? value) {
    return value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }
}

class HiredPassApiException implements Exception {
  const HiredPassApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
