import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class LearningApiConfig {
  const LearningApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration requestTimeout;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
}

class BackendLearningRepository implements LearningRepository {
  BackendLearningRepository({
    required LearningApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final LearningApiConfig _config;
  final http.Client _client;

  @override
  Future<LearningDashboard> fetchDashboard() async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/learning/dashboard?window=30d',
    );
    return LearningDashboard.fromJson(data);
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {
    await _request(
      method: 'POST',
      path: '/learning/recommendations/$recommendationId/events',
      body: <String, dynamic>{
        'idempotencyKey': 'mobile-learning-$eventType-$recommendationId',
        'eventType': eventType,
        'dismissalReason': ?dismissalReason,
      },
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    if (!_config.hasAccessToken) {
      throw const LearningApiException(
        'Analitik belajar membutuhkan sesi login.',
      );
    }
    final Uri uri = Uri.parse('${_config.baseUrl}$path');
    final http.Response response = method == 'GET'
        ? await _client
              .get(uri, headers: _headers)
              .timeout(_config.requestTimeout)
        : await _client
              .post(uri, headers: _headers, body: jsonEncode(body))
              .timeout(_config.requestTimeout);
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode == 503) {
      throw const LearningUnavailableException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map
          ? decoded['message']?.toString() ?? 'Gagal memuat Learning.'
          : 'Gagal memuat Learning.';
      throw LearningApiException(message);
    }
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const LearningApiException(
        'Learning API mengembalikan data yang tidak valid.',
      );
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer ${_config.accessToken}',
    'content-type': 'application/json',
  };
}

class LearningApiException implements Exception {
  const LearningApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LearningUnavailableException extends LearningApiException {
  const LearningUnavailableException()
    : super('Learning V2 belum tersedia untuk akun ini.');
}
