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

    return HiredPassStatus(
      passPoints: _int(data['passPoints']),
      missions: missions,
    );
  }

  static int _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void dispose() {
    _client.close();
  }
}

class HiredPassApiException implements Exception {
  const HiredPassApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
