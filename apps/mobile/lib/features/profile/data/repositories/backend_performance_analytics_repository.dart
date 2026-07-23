import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/profile/data/repositories/performance_analytics_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';

class PerformanceAnalyticsApiConfig {
  const PerformanceAnalyticsApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
    this.requestTimeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration requestTimeout;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
}

class BackendPerformanceAnalyticsRepository
    implements PerformanceAnalyticsRepository {
  BackendPerformanceAnalyticsRepository({
    required PerformanceAnalyticsApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final PerformanceAnalyticsApiConfig _config;
  final http.Client _client;

  @override
  Future<PerformanceAnalytics> fetchPerformance() async {
    if (!_config.hasAccessToken) {
      throw const PerformanceAnalyticsApiException(
        'Sesi loginmu sudah berakhir. Silakan masuk kembali.',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${_config.baseUrl}/analytics'),
            headers: <String, String>{
              'authorization': 'Bearer ${_config.accessToken}',
              'content-type': 'application/json',
            },
          )
          .timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const PerformanceAnalyticsApiException(
        'Ringkasan performa membutuhkan waktu terlalu lama. Coba lagi.',
      );
    }

    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const PerformanceAnalyticsApiException(
        'Ringkasan performa belum dapat dibaca. Silakan coba lagi.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PerformanceAnalyticsApiException(
        _messageForStatus(response.statusCode),
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const PerformanceAnalyticsApiException(
        'Ringkasan performa belum dapat dibaca. Silakan coba lagi.',
      );
    }

    return PerformanceAnalytics.fromJson(
      decoded['data'] as Map<String, dynamic>,
    );
  }

  String _messageForStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Sesi loginmu sudah berakhir. Silakan masuk kembali.';
    }
    if (statusCode >= 500) {
      return 'Ringkasan performa sedang tidak tersedia. Coba lagi sebentar.';
    }
    return 'Ringkasan performa belum berhasil dimuat. Silakan coba lagi.';
  }
}

class PerformanceAnalyticsApiException implements Exception {
  const PerformanceAnalyticsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
