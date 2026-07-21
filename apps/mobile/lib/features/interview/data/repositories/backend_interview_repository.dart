import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

class InterviewApiConfig {
  const InterviewApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
  });

  final String baseUrl;
  final String? accessToken;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
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
  Future<List<InterviewSessionSummaryRecord>> listSessions() async {
    final Map<String, dynamic> body = await _get('/interview/sessions');
    final Object? sessionsJson = body['sessions'];
    if (sessionsJson is! List) {
      return const <InterviewSessionSummaryRecord>[];
    }

    return sessionsJson
        .whereType<Map<String, dynamic>>()
        .map(_sessionSummaryFromJson)
        .toList(growable: false);
  }

  @override
  Future<InterviewSessionDetailRecord> getSession(String sessionId) async {
    final Map<String, dynamic> body = await _get(
      '/interview/sessions/$sessionId',
    );
    final Object? turnsJson = body['turns'];
    final List<InterviewMessage> messages = turnsJson is List
        ? turnsJson
              .whereType<Map<String, dynamic>>()
              .map(_messageFromTurnJson)
              .toList(growable: false)
        : const <InterviewMessage>[];

    return InterviewSessionDetailRecord(
      sessionId: body['sessionId'] as String? ?? sessionId,
      status: body['status'] as String? ?? 'active',
      companyId: body['companyId'] as String? ?? '',
      targetRole: body['targetRole'] as String? ?? '',
      mode: body['mode'] as String? ?? '',
      responseStyle: body['responseStyle'] as String? ?? 'text',
      messages: messages,
      finalSummary: body['finalSummary'] is Map<String, dynamic>
          ? InterviewFinalSummary.fromJson(
              body['finalSummary'] as Map<String, dynamic>,
            )
          : null,
    );
  }

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
          'responseStyle': config.responseStyle,
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

  @override
  Future<String> transcribeAnswerAudio({
    required String sessionId,
    required List<int> audioBytes,
    required String filename,
  }) async {
    _ensureAuthenticated();

    final Uri uri = Uri.parse(
      '${_config.baseUrl}/interview/sessions/$sessionId/speech/transcriptions',
    );
    final http.MultipartRequest request = http.MultipartRequest('POST', uri);
    request.headers.addAll(<String, String>{
      'authorization': 'Bearer ${_config.accessToken}',
    });
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: filename),
    );

    final http.StreamedResponse streamedResponse = await _client.send(request);
    final http.Response response =
        await http.Response.fromStream(streamedResponse);
    final Map<String, dynamic> decoded = _decodeResponse(response);

    final Object? transcriptObj = decoded['transcript'];
    if (transcriptObj is Map<String, dynamic>) {
      return transcriptObj['text'] as String? ?? '';
    }
    final Object? answerObj = decoded['answer'];
    if (answerObj is Map<String, dynamic>) {
      return answerObj['text'] as String? ?? '';
    }

    throw const InterviewApiException('Transkripsi audio gagal diproses.');
  }

  @override
  String getQuestionAudioUrl({
    required String sessionId,
    required String turnId,
  }) {
    return '${_config.baseUrl}/interview/sessions/$sessionId/speech/questions/$turnId/audio';
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    _ensureAuthenticated();

    final Uri uri = Uri.parse('${_config.baseUrl}$path');
    final http.Response response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    _ensureAuthenticated();

    final Uri uri = Uri.parse('${_config.baseUrl}$path');
    final http.Response response = await _client.get(uri, headers: _headers);

    return _decodeResponse(response);
  }

  void _ensureAuthenticated() {
    if (!_config.hasAccessToken) {
      throw const InterviewApiException(
        'Interview AI membutuhkan sesi login Supabase. Silakan masuk ulang.',
      );
    }
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer ${_config.accessToken}',
    'content-type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
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
      id: json['turnId'] as String? ?? json['id'] as String? ?? '',
      author: InterviewMessageAuthor.interviewer,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.now(),
      audioAvailable: json['audioAvailable'] as bool? ?? false,
    );
  }

  InterviewSessionSummaryRecord _sessionSummaryFromJson(
    Map<String, dynamic> json,
  ) {
    return InterviewSessionSummaryRecord(
      sessionId: json['sessionId'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      companyId: json['companyId'] as String? ?? '',
      targetRole: json['targetRole'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      language: json['language'] as String? ?? '',
      responseStyle: json['responseStyle'] as String? ?? 'text',
      finalSummary: json['finalSummary'] is Map<String, dynamic>
          ? InterviewFinalSummary.fromJson(
              json['finalSummary'] as Map<String, dynamic>,
            )
          : null,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  InterviewMessage _messageFromTurnJson(Map<String, dynamic> json) {
    final String role = json['role'] as String? ?? 'question';
    return InterviewMessage(
      id: json['turnId'] as String? ?? '',
      author: role == 'answer'
          ? InterviewMessageAuthor.candidate
          : InterviewMessageAuthor.interviewer,
      text: json['text'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      evaluation: json['evaluation'] is Map<String, dynamic>
          ? InterviewEvaluation.fromJson(
              json['evaluation'] as Map<String, dynamic>,
            )
          : null,
      audioAvailable: json['audioAvailable'] as bool? ?? false,
    );
  }

  DateTime _parseDateTime(Object? rawValue) {
    final String? text = rawValue?.toString();
    if (text == null || text.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(text)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class InterviewApiException implements Exception {
  const InterviewApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
