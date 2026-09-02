import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/pvp_insights/domain/pvp_insights.dart';

class PvpInsightsRepository {
  PvpInsightsRepository({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  final String? accessToken;
  final http.Client _client;

  Future<PvpInsightsDashboard> fetch({
    required PvpInsightsWindow window,
    required PvpInsightsMode mode,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/pvp/analytics').replace(
      queryParameters: <String, String>{
        'window': window.apiValue,
        'mode': mode.apiValue,
      },
    );
    final response = await _client.get(
      uri,
      headers: <String, String>{
        'content-type': 'application/json',
        if ((accessToken ?? '').trim().isNotEmpty)
          'authorization': 'Bearer $accessToken',
      },
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw StateError(message ?? 'PvP Insights belum dapat dimuat.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Respons PvP Insights tidak valid.');
    }
    return PvpInsightsDashboard.fromJson(decoded);
  }
}
