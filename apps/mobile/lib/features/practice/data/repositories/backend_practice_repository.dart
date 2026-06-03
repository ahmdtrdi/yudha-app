import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/practice/data/repositories/mock_practice_repository.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class PracticeApiConfig {
  const PracticeApiConfig({this.baseUrl = AppConfig.apiBaseUrl});

  final String baseUrl;
}

class BackendPracticeRepository implements PracticeRepository {
  BackendPracticeRepository({
    required PracticeApiConfig config,
    http.Client? client,
    PracticeRepository? fallbackRepository,
  }) : _config = config,
       _client = client ?? http.Client(),
       _fallbackRepository =
           fallbackRepository ?? const MockPracticeRepository();

  final PracticeApiConfig _config;
  final http.Client _client;
  final PracticeRepository _fallbackRepository;

  @override
  Future<PracticeDashboard> fetchDashboard({
    required ProfileTarget target,
  }) async {
    try {
      final Uri uri = Uri.parse(
        '${_config.baseUrl}/practice/dashboard?target=${target.name}',
      );
      final Object? decoded = await _getJson(uri);
      if (decoded is! Map<String, dynamic>) {
        throw const PracticeApiException(
          'Practice dashboard returned invalid JSON.',
        );
      }
      return _dashboardFromJson(decoded);
    } catch (_) {
      return _fallbackRepository.fetchDashboard(target: target);
    }
  }

  @override
  Future<List<PracticeQuestion>> fetchQuestions({
    required String topicId,
  }) async {
    try {
      final Uri uri = Uri.parse(
        '${_config.baseUrl}/practice/topics/$topicId/questions',
      );
      final Object? decoded = await _getJson(uri);
      if (decoded is! List) {
        throw const PracticeApiException(
          'Practice questions returned invalid JSON.',
        );
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_questionFromJson)
          .toList(growable: false);
    } catch (_) {
      return _fallbackRepository.fetchQuestions(topicId: topicId);
    }
  }

  Future<Object?> _getJson(Uri uri) async {
    final http.Response response = await _client.get(
      uri,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    final Object? decoded = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PracticeApiException(
        decoded is Map<String, dynamic>
            ? decoded['message']?.toString() ?? response.reasonPhrase ?? 'Error'
            : response.reasonPhrase ?? 'Error',
      );
    }
    return decoded;
  }

  PracticeDashboard _dashboardFromJson(Map<String, dynamic> json) {
    final List<PracticeTopic> topics =
        (json['topics'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_topicFromJson)
            .toList(growable: false);
    final Map<String, dynamic> questionJson =
        json['questionOfDay'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final List<PracticeRecentActivity> recentActivities =
        (json['recentActivities'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(_recentActivityFromJson)
            .toList(growable: false);

    return PracticeDashboard(
      topics: topics,
      questionOfDay: _questionFromJson(questionJson),
      overallProgressPercent: _readInt(
        json['overallProgressPercent'],
      ).clamp(0, 100),
      recentActivities: recentActivities,
    );
  }

  PracticeTopic _topicFromJson(Map<String, dynamic> json) {
    return PracticeTopic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      groupTitle: json['groupTitle']?.toString() ?? 'Topik Latihan',
      badgeLabel: json['badgeLabel']?.toString(),
      questionCount: _readInt(json['questionCount']),
      isLocked: json['isLocked'] == true,
    );
  }

  PracticeQuestion _questionFromJson(Map<String, dynamic> json) {
    return PracticeQuestion(
      id: json['id']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      topicName: json['topicName']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
      isQuestionOfDay: json['isQuestionOfDay'] == true,
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> option) => PracticeOption(
              id: option['id']?.toString() ?? '',
              label: option['label']?.toString() ?? '',
              isCorrect: option['isCorrect'] == true,
            ),
          )
          .toList(growable: false),
    );
  }

  PracticeRecentActivity _recentActivityFromJson(Map<String, dynamic> json) {
    return PracticeRecentActivity(
      type: _recentActivityTypeFromName(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      scoreLabel: json['scoreLabel']?.toString() ?? '',
    );
  }

  PracticeRecentActivityType _recentActivityTypeFromName(String? name) {
    return switch (name) {
      'insight' => PracticeRecentActivityType.insight,
      'interview' => PracticeRecentActivityType.interview,
      _ => PracticeRecentActivityType.quiz,
    };
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class PracticeApiException implements Exception {
  const PracticeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
