import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

class DailyReminderApiConfig {
  const DailyReminderApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
  });

  final String baseUrl;
  final String? accessToken;
}

class DailyReminderRepository {
  DailyReminderRepository({
    required DailyReminderApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final DailyReminderApiConfig _config;
  final http.Client _client;

  Future<DailyReminderPreferences> fetchPreferences() async {
    final data = await _request('GET', '/notifications/preferences');
    return DailyReminderPreferences.fromJson(data);
  }

  Future<DailyReminderPreferences> updatePreferences(
    Map<String, Object?> update,
  ) async {
    final data = await _request(
      'PATCH',
      '/notifications/preferences',
      body: update,
    );
    return DailyReminderPreferences.fromJson(data);
  }

  Future<void> registerInstallation({
    required String installationId,
    required String token,
    required String platform,
    required String timeZone,
  }) async {
    await _request(
      'PUT',
      '/notifications/installations/$installationId',
      body: <String, Object?>{
        'token': token,
        'platform': platform,
        'timeZone': timeZone,
      },
    );
  }

  Future<void> removeInstallation(String installationId) async {
    await _request('DELETE', '/notifications/installations/$installationId');
  }

  Future<void> markOpened(String deliveryId) async {
    await _request('POST', '/notifications/deliveries/$deliveryId/open');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = _config.accessToken?.trim();
    if (token == null || token.isEmpty) {
      throw const DailyReminderApiException('Sesi login sudah berakhir.');
    }
    final uri = Uri.parse('${_config.baseUrl}$path');
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    final http.Response response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'PATCH' => await _client.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      'PUT' => await _client.put(uri, headers: headers, body: jsonEncode(body)),
      'POST' => await _client.post(uri, headers: headers),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw StateError('Unsupported request method $method'),
    };
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? ((decoded['error'] as Map?)?['message'] ??
                    decoded['message'] ??
                    response.reasonPhrase ??
                    'Request failed')
                .toString()
          : response.reasonPhrase ?? 'Request failed';
      throw DailyReminderApiException(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DailyReminderApiException('Respons notifikasi tidak valid.');
    }
    final Object? data = decoded['data'];
    return data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
  }
}

class DailyReminderApiException implements Exception {
  const DailyReminderApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
