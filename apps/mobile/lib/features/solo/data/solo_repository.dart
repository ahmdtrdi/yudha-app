import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

class SoloApiException implements Exception {
  const SoloApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SoloRepository {
  SoloRepository({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  final String? accessToken;
  final http.Client _client;

  Future<SoloSession> create({
    required SoloQuestionCount questionCount,
    required String characterId,
  }) => _post('/solo/sessions', <String, dynamic>{
    'idempotencyKey': _key('create'),
    'mechanicMode': 'standard',
    'questionCount': questionCount.value,
    'questionSelection': <String, dynamic>{'type': 'balanced'},
    'characterId': characterId,
  }).then(SoloSession.fromJson);

  Future<SoloSession> get(String sessionId) =>
      _get('/solo/sessions/$sessionId').then(SoloSession.fromJson);

  Future<SoloSession?> active() async {
    final data = await _get('/solo/active-session');
    final active = data['activeSession'];
    return active is Map<String, dynamic> ? SoloSession.fromJson(active) : null;
  }

  Future<SoloQuestion> open(String sessionId, String questionId) => _post(
    '/solo/sessions/$sessionId/questions/$questionId/open',
    <String, dynamic>{'idempotencyKey': _key('open')},
  ).then(SoloQuestion.fromJson);

  Future<SoloHint> requestHint(String sessionId, String questionId) => _post(
    '/solo/sessions/$sessionId/questions/$questionId/hint',
    <String, dynamic>{'idempotencyKey': _key('hint')},
  ).then(SoloHint.fromJson);

  Future<SoloAnswerResponse> answer(
    String sessionId,
    String questionId,
    int? optionIndex, {
    int? clientActiveResponseTimeMs,
    int? backgroundDurationMs,
  }) => _post('/solo/sessions/$sessionId/answers', <String, dynamic>{
    'idempotencyKey': _key('answer'),
    'sessionQuestionId': questionId,
    'selectedOptionIndex': optionIndex,
    'clientActiveResponseTimeMs': ?clientActiveResponseTimeMs,
    'backgroundDurationMs': ?backgroundDurationMs,
  }).then(SoloAnswerResponse.fromJson);

  Future<SoloSession> stop(String sessionId) => _post(
    '/solo/sessions/$sessionId/finish',
    <String, dynamic>{'idempotencyKey': _key('stop')},
  ).then(SoloSession.fromJson);

  Future<Map<String, dynamic>> _get(String path) async {
    _auth();
    final response = await _client
        .get(Uri.parse('${AppConfig.apiBaseUrl}$path'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    _auth();
    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
  };

  void _auth() {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const SoloApiException('Sesi login diperlukan untuk latihan Solo.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      throw SoloApiException(
        error is Map<String, dynamic>
            ? error['message']?.toString() ?? 'Solo gagal diproses.'
            : decoded is Map<String, dynamic>
            ? decoded['message']?.toString() ?? 'Solo gagal diproses.'
            : 'Solo gagal diproses.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const SoloApiException('Respons Solo tidak valid.');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  String _key(String operation) =>
      'mobile-solo-$operation-${DateTime.now().microsecondsSinceEpoch}';
}
