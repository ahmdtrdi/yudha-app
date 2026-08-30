import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_company_option.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';

class InterviewApiConfig {
  const InterviewApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
    this.requestTimeout = const Duration(seconds: 30),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration requestTimeout;

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
  Future<List<InterviewCompanyOption>> listCompanies() async {
    final Map<String, dynamic> body = await _get(
      '/interview/companies',
      timeoutMessage: 'Daftar perusahaan belum berhasil dimuat. Coba lagi.',
      connectionMessage:
          'Daftar perusahaan belum dapat dihubungi. Periksa koneksi lalu coba lagi.',
    );
    final Object? companiesJson = body['companies'];
    if (companiesJson is! List) {
      throw const InterviewApiException(
        'Daftar perusahaan belum dapat dibaca. Silakan coba lagi.',
      );
    }

    return companiesJson
        .map((Object? rawCompany) {
          if (rawCompany is! Map<String, dynamic>) {
            throw const InterviewApiException(
              'Daftar perusahaan belum dapat dibaca. Silakan coba lagi.',
            );
          }
          final Object? rawId = rawCompany['id'];
          final Object? rawName = rawCompany['name'];
          final Object? rawDefaultRole = rawCompany['defaultRole'];
          if (rawId is! String ||
              rawId.trim().isEmpty ||
              rawName is! String ||
              rawName.trim().isEmpty ||
              (rawDefaultRole != null && rawDefaultRole is! String)) {
            throw const InterviewApiException(
              'Daftar perusahaan belum dapat dibaca. Silakan coba lagi.',
            );
          }

          final String? defaultRole = rawDefaultRole is String
              ? rawDefaultRole.trim()
              : null;
          return InterviewCompanyOption(
            id: rawId.trim(),
            name: rawName.trim(),
            defaultRole: defaultRole == null || defaultRole.isEmpty
                ? null
                : defaultRole,
          );
        })
        .toList(growable: false);
  }

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
    final Map<String, dynamic> body;
    try {
      body = await _post(
        '/interview/sessions/$sessionId/turns',
        <String, dynamic>{
          'idempotencyKey': idempotencyKey,
          'answer': <String, dynamic>{'type': 'text', 'text': answer},
        },
      );
    } on InterviewApiException catch (error) {
      if (error.requiresNewIdempotencyKey) {
        throw InterviewAnswerRetryRequiredException(error.message);
      }
      rethrow;
    }

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

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client
          .send(request)
          .timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const InterviewApiException(
        'Transkripsi membutuhkan waktu terlalu lama. Coba rekam ulang.',
      );
    } on http.ClientException {
      throw const InterviewApiException(
        'Rekaman belum dapat dikirim. Periksa koneksi lalu coba lagi.',
      );
    }
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );
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
    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const InterviewApiException(
        'Pewawancara AI belum merespons. Coba lagi sebentar.',
      );
    } on http.ClientException {
      throw const InterviewApiException(
        'Pewawancara AI belum dapat dihubungi. Periksa koneksi lalu coba lagi.',
      );
    }

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String timeoutMessage = 'Sesi interview belum berhasil dimuat. Coba lagi.',
    String connectionMessage =
        'Sesi interview belum dapat dihubungi. Periksa koneksi lalu coba lagi.',
  }) async {
    _ensureAuthenticated();

    final Uri uri = Uri.parse('${_config.baseUrl}$path');
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(_config.requestTimeout);
    } on TimeoutException {
      throw InterviewApiException(timeoutMessage);
    } on http.ClientException {
      throw InterviewApiException(connectionMessage);
    }

    return _decodeResponse(response);
  }

  void _ensureAuthenticated() {
    if (!_config.hasAccessToken) {
      throw const InterviewApiException(
        'Sesi login sudah berakhir. Silakan masuk ulang.',
      );
    }
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer ${_config.accessToken}',
    'content-type': 'application/json',
  };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const InterviewApiException(
        'Respons interview belum dapat dibaca. Silakan coba lagi.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String backendMessage = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
          : response.reasonPhrase ?? 'Error';
      throw InterviewApiException(
        _friendlyErrorMessage(response.statusCode, backendMessage),
        requiresNewIdempotencyKey: backendMessage.toLowerCase().contains(
          'submit a new request',
        ),
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const InterviewApiException(
      'Respons interview belum dapat dibaca. Silakan coba lagi.',
    );
  }

  String _friendlyErrorMessage(int statusCode, String backendMessage) {
    final String normalized = backendMessage.toLowerCase();
    if (statusCode == 401 || statusCode == 403) {
      return 'Sesi loginmu sudah berakhir. Silakan masuk kembali.';
    }
    if (statusCode == 404 && normalized.contains('company')) {
      return 'Profil perusahaan ini belum tersedia. Pilih perusahaan lain.';
    }
    if (statusCode == 404) {
      return 'Sesi interview ini tidak ditemukan.';
    }
    if (normalized.contains('submit at least one')) {
      return 'Jawab setidaknya satu pertanyaan sebelum menyelesaikan sesi.';
    }
    if (normalized.contains('still processing')) {
      return 'Jawabanmu masih sedang dinilai. Tunggu sebentar lalu coba lagi.';
    }
    if (normalized.contains('submit a new request')) {
      return 'Jawaban sebelumnya belum berhasil dinilai. Kirim ulang jawabanmu.';
    }
    if (statusCode == 409 || normalized.contains('not active')) {
      return 'Sesi interview ini sudah selesai.';
    }
    if (statusCode == 413) {
      return 'Rekaman terlalu besar. Coba rekam jawaban yang lebih singkat.';
    }
    if (statusCode == 429) {
      return 'Pewawancara AI sedang ramai. Tunggu sebentar lalu coba lagi.';
    }
    if (statusCode == 400 && normalized.contains('5000')) {
      return 'Jawaban terlalu panjang. Ringkas menjadi maksimal 5.000 karakter.';
    }
    if (statusCode == 400 && normalized.contains('audio')) {
      return 'Format atau ukuran rekaman belum didukung. Coba rekam ulang.';
    }
    if (statusCode >= 500 ||
        normalized.contains('model') ||
        normalized.contains('provider')) {
      return 'Pewawancara AI sedang tidak tersedia. Coba lagi sebentar.';
    }
    return 'Permintaan interview belum berhasil. Silakan coba lagi.';
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
  const InterviewApiException(
    this.message, {
    this.requiresNewIdempotencyKey = false,
  });

  final String message;
  final bool requiresNewIdempotencyKey;

  @override
  String toString() => message;
}
