import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_history_batch.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class PracticeApiConfig {
  const PracticeApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration requestTimeout;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
}

class BackendPracticeRepository implements PracticeRepository {
  BackendPracticeRepository({
    required PracticeApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final PracticeApiConfig _config;
  final http.Client _client;

  @override
  Future<PracticeDashboard> fetchDashboard() async {
    final Map<String, dynamic> data = await _get('/practice/dashboard');
    final Map<String, dynamic> summary = _readMap(data['summary']);
    final List<PracticeTopic> topics =
        (data['categories'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .expand(_topicsFromCategory)
            .toList(growable: false);
    final List<PracticeRecentActivity> recentActivities =
        (data['recentSessions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_recentActivityFromJson)
            .toList(growable: false);

    return PracticeDashboard(
      topics: topics,
      overallProgressPercent: _readDouble(
        summary['averageAccuracy'],
      ).round().clamp(0, 100),
      recentActivities: recentActivities,
    );
  }

  @override
  Future<PracticeHistoryBatch> fetchHistory({
    required int limit,
    required int offset,
  }) async {
    final Uri uri = Uri(
      path: '/practice/history',
      queryParameters: <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    final Map<String, dynamic> data = await _get(uri.toString());
    final List<PracticeRecentActivity> items =
        (data['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_recentActivityFromJson)
            .toList(growable: false);
    return PracticeHistoryBatch(
      items: items,
      limit: _readInt(data['limit']),
      offset: _readInt(data['offset']),
      total: _readInt(data['total']),
    );
  }

  @override
  Future<PracticeSession> startSession({
    required String category,
    String? subcategory,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/practice/sessions',
      <String, dynamic>{'category': category, 'subcategory': subcategory},
    );
    final List<PracticeQuestion> questions =
        (data['questions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_questionFromJson)
            .toList(growable: false);

    if (questions.isEmpty) {
      throw const PracticeApiException(
        'Server tidak mengembalikan soal untuk sesi ini.',
      );
    }

    return PracticeSession(
      id: data['sessionId']?.toString() ?? '',
      category: data['category']?.toString() ?? category,
      subcategory: data['subcategory']?.toString(),
      totalQuestions: _readInt(data['totalQuestions']),
      questions: questions,
    );
  }

  @override
  Future<PracticeAnswerResult> submitAnswer({
    required String sessionId,
    required String sessionQuestionId,
    required int selectedOptionIndex,
    required int responseTimeMs,
    required bool usedHint,
  }) async {
    final Map<String, dynamic> data =
        await _post('/practice/sessions/$sessionId/answers', <String, dynamic>{
          'idempotencyKey': _requestId('answer'),
          'sessionQuestionId': sessionQuestionId,
          'selectedOptionIndex': selectedOptionIndex,
          'responseTimeMs': responseTimeMs,
          'usedHint': usedHint,
        });

    final Map<String, dynamic> progress = _readMap(data['progress']);
    return PracticeAnswerResult(
      isCorrect: data['isCorrect'] == true,
      correctOptionIndex: _readInt(data['correctOptionIndex']),
      explanation: data['explanation']?.toString(),
      scoreGained: _readInt(data['scoreGained']),
      progress: PracticeSessionSummary(
        totalQuestions: _readInt(progress['totalQuestions']),
        answeredCount: _readInt(progress['answeredCount']),
        correctCount: _readInt(progress['correctCount']),
        accuracy: _readDouble(progress['accuracy']),
        totalScore: _readInt(progress['totalScore']),
      ),
    );
  }

  @override
  Future<PracticeSessionSummary> finishSession({
    required String sessionId,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/practice/sessions/$sessionId/finish',
      <String, dynamic>{'idempotencyKey': _requestId('finish')},
    );

    return PracticeSessionSummary(
      totalQuestions: _readInt(data['totalQuestions']),
      answeredCount: _readInt(data['answeredCount']),
      correctCount: _readInt(data['correctCount']),
      accuracy: _readDouble(data['accuracy']),
      totalScore: _readInt(data['totalScore']),
    );
  }

  Future<Map<String, dynamic>> _get(String path) async {
    _ensureAuthenticated();
    final http.Response response = await _client
        .get(Uri.parse('${_config.baseUrl}$path'), headers: _headers)
        .timeout(_config.requestTimeout);
    return _decodeData(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    _ensureAuthenticated();
    final http.Response response = await _client
        .post(
          Uri.parse('${_config.baseUrl}$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_config.requestTimeout);
    return _decodeData(response);
  }

  void _ensureAuthenticated() {
    if (!_config.hasAccessToken) {
      throw const PracticeApiException(
        'Latihan membutuhkan sesi login. Silakan masuk ulang.',
      );
    }
  }

  Map<String, String> get _headers => <String, String>{
    'authorization': 'Bearer ${_config.accessToken}',
    'content-type': 'application/json',
  };

  String _requestId(String operation) {
    return 'mobile-practice-$operation-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, dynamic> _decodeData(http.Response response) {
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
          : response.reasonPhrase ?? 'Error';
      throw PracticeApiException(message);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const PracticeApiException(
        'Practice API mengembalikan data yang tidak valid.',
      );
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Iterable<PracticeTopic> _topicsFromCategory(Map<String, dynamic> json) {
    final String category = json['category']?.toString() ?? '';
    final String label = _humanizeIdentifier(
      json['label']?.toString() ?? category,
    );
    final List<Map<String, dynamic>> subcategories =
        (json['subcategories'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    if (subcategories.isEmpty) {
      return <PracticeTopic>[
        PracticeTopic(
          id: category,
          category: category,
          name: label,
          description: 'Sesi latihan dengan 5 soal.',
          groupTitle: 'KATEGORI LATIHAN',
          badgeLabel: _humanizeIdentifier(category),
          questionCount: _readInt(json['availableQuestions']),
        ),
      ];
    }

    return subcategories.map((Map<String, dynamic> item) {
      final String subcategory = item['subcategory']?.toString() ?? '';
      return PracticeTopic(
        id: '$category::$subcategory',
        category: category,
        subcategory: subcategory,
        name: _humanizeIdentifier(subcategory),
        description: 'Sesi latihan dengan 5 soal.',
        groupTitle: label.toUpperCase(),
        badgeLabel: _humanizeIdentifier(category),
        questionCount: _readInt(item['availableQuestions']),
      );
    });
  }

  PracticeQuestion _questionFromJson(Map<String, dynamic> json) {
    final String category = json['category']?.toString() ?? '';
    final String? subcategory = json['subcategory']?.toString();
    final List<dynamic> rawOptions =
        json['options'] as List<dynamic>? ?? const <dynamic>[];

    return PracticeQuestion(
      id: json['questionId']?.toString() ?? '',
      sessionQuestionId: json['sessionQuestionId']?.toString() ?? '',
      topicId: subcategory == null ? category : '$category::$subcategory',
      topicName: _humanizeIdentifier(subcategory ?? category),
      prompt: json['prompt']?.toString() ?? '',
      options: List<PracticeOption>.generate(rawOptions.length, (int index) {
        final Object? rawOption = rawOptions[index];
        final String label = rawOption is Map<String, dynamic>
            ? rawOption['label']?.toString() ?? ''
            : rawOption?.toString() ?? '';
        return PracticeOption(id: index.toString(), label: label, index: index);
      }, growable: false),
      hint: json['hint']?.toString() ?? '',
      questionOrder: _readInt(json['questionOrder']),
      timeLimitSeconds: _readInt(json['timeLimitSeconds']),
    );
  }

  PracticeRecentActivity _recentActivityFromJson(Map<String, dynamic> json) {
    final String category = json['category']?.toString() ?? 'Latihan';
    final String? subcategory = json['subcategory']?.toString();
    final int answered = _readInt(json['answeredCount']);
    final int total = _readInt(json['totalQuestions']);
    return PracticeRecentActivity(
      type: PracticeRecentActivityType.quiz,
      title: subcategory == null
          ? _humanizeIdentifier(category)
          : '${_humanizeIdentifier(category)} - '
                '${_humanizeIdentifier(subcategory)}',
      subtitle: '$answered dari $total soal',
      scoreLabel: '${_readDouble(json['accuracy']).round()}%',
    );
  }

  Map<String, dynamic> _readMap(Object? value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _humanizeIdentifier(String value) {
    const Set<String> acronyms = <String>{
      'akhlak',
      'bumn',
      'cpns',
      'nkri',
      'tiu',
      'tkp',
      'twk',
      'uud',
    };
    return value
        .trim()
        .split(RegExp(r'[-_\s]+'))
        .where((String part) => part.isNotEmpty)
        .map((String part) {
          final String lowercase = part.toLowerCase();
          if (acronyms.contains(lowercase)) {
            return lowercase.toUpperCase();
          }
          return '${lowercase[0].toUpperCase()}${lowercase.substring(1)}';
        })
        .join(' ');
  }
}

class PracticeApiException implements Exception {
  const PracticeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
