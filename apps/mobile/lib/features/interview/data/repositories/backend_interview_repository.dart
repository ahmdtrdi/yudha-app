import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

class InterviewApiConfig {
  const InterviewApiConfig({
    this.baseUrl = const String.fromEnvironment(
      'YUDHA_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    ),
    this.accessToken = const String.fromEnvironment(
      'YUDHA_SUPABASE_ACCESS_TOKEN',
    ),
  });

  final String baseUrl;
  final String accessToken;

  bool get hasAccessToken => accessToken.trim().isNotEmpty;
}

class BackendInterviewRepository implements InterviewRepository {
  BackendInterviewRepository({
    required InterviewApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final InterviewApiConfig _config;
  final http.Client _client;

  @override
  Future<InterviewStartResult> startSession(
    InterviewLaunchConfig config,
  ) async {
    final Map<String, dynamic> body =
        await _post('/interview/sessions', <String, dynamic>{
          'mode': config.mode,
          'targetRole': config.targetRole,
          'companyId': config.companyId,
          'language': config.language,
          'responseStyle': 'text',
        });

    final Map<String, dynamic> question =
        body['openingQuestion'] as Map<String, dynamic>;
    return InterviewStartResult(
      sessionId: body['sessionId'] as String,
      status: body['status'] as String,
      openingQuestion: _questionFromJson(question),
    );
  }

  @override
  Future<InterviewTurnResult> submitAnswer({
    required String sessionId,
    required String answer,
    required String idempotencyKey,
  }) async {
    final Map<String, dynamic> body = await _post(
      '/interview/sessions/$sessionId/turns',
      <String, dynamic>{
        'idempotencyKey': idempotencyKey,
        'answer': <String, dynamic>{'type': 'text', 'text': answer},
      },
    );

    final Object? nextQuestionJson = body['nextQuestion'];
    final Object? evaluationJson = body['evaluation'];
    final Object? finalSummaryJson = body['finalSummary'];

    return InterviewTurnResult(
      sessionId: body['sessionId'] as String,
      status: body['status'] as String,
      nextQuestion: nextQuestionJson is Map<String, dynamic>
          ? _questionFromJson(nextQuestionJson)
          : null,
      evaluation: evaluationJson is Map<String, dynamic>
          ? InterviewEvaluation.fromJson(evaluationJson)
          : null,
      finalSummary: finalSummaryJson is Map<String, dynamic>
          ? InterviewFinalSummary.fromJson(finalSummaryJson)
          : null,
    );
  }

  @override
  Future<InterviewFinalSummary> completeSession(String sessionId) async {
    final Map<String, dynamic> body = await _post(
      '/interview/sessions/$sessionId/complete',
      const <String, dynamic>{},
    );
    final Object? finalSummaryJson = body['finalSummary'];
    if (finalSummaryJson is Map<String, dynamic>) {
      return InterviewFinalSummary.fromJson(finalSummaryJson);
    }
    throw const InterviewApiException('Session summary is not available yet.');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!_config.hasAccessToken) {
      throw const InterviewApiException(
        'Interview AI needs a Supabase access token. Run with '
        '--dart-define=YUDHA_SUPABASE_ACCESS_TOKEN=<token> until mobile auth '
        'is wired.',
      );
    }

    final Uri uri = Uri.parse('${_config.baseUrl}$path');
    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'authorization': 'Bearer ${_config.accessToken}',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
          : response.reasonPhrase ?? 'Error';
      throw InterviewApiException(message);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const InterviewApiException('Interview API returned invalid JSON.');
  }

  InterviewMessage _questionFromJson(Map<String, dynamic> json) {
    return InterviewMessage(
      id: json['turnId'] as String,
      author: InterviewMessageAuthor.interviewer,
      text: json['text'] as String,
      createdAt: DateTime.now(),
    );
  }
}

class InterviewApiException implements Exception {
  const InterviewApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
