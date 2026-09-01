import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

void main() {
  test('preserves unavailable metrics as null and parses confidence metadata', () {
    final LearningDashboard dashboard = LearningDashboard.fromJson(
      _dashboardJson(),
    );

    expect(dashboard.accuracy.value, isNull);
    expect(dashboard.accuracy.attemptCount, 0);
    expect(dashboard.accuracy.confidence, 'low');
    expect(dashboard.pace.value, isNull);
    expect(dashboard.assessment.status, 'not_available');
    expect(dashboard.nextAction?.skillLabel, 'TIU Numerik');
    expect(dashboard.nextAction?.runnable, isTrue);
  });

  test('low confidence never changes a skill into a weak label', () {
    final LearningDashboard dashboard = LearningDashboard.fromJson(
      _dashboardJson(
        skillStates: <Map<String, dynamic>>[
          <String, dynamic>{
            'skillId': 'cpns.twk',
            'label': 'TWK',
            'status': 'needs_repair',
            'evidenceConfidence': 'low',
            'unseenIndependentAccuracy': <String, dynamic>{
              'value': 0,
              'correctCount': 0,
              'attemptCount': 1,
              'uniqueQuestionCount': 1,
              'confidence': 'low',
            },
          },
        ],
      ),
    );

    expect(dashboard.skillStates.single.status, 'needs_repair');
    expect(dashboard.skillStates.single.confidence, 'low');
  });
}

Map<String, dynamic> _dashboardJson({
  List<Map<String, dynamic>> skillStates = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'asOf': '2026-09-01T02:00:00.000Z',
  'calculationVersion': 'learning-v1',
  'target': 'cpns',
  'nextAction': <String, dynamic>{
    'recommendationId': 'recommendation-1',
    'target': 'cpns',
    'objective': 'repair_accuracy',
    'skill': <String, dynamic>{
      'id': 'cpns.tiu.numerik',
      'label': 'TIU Numerik',
      'category': 'tiu',
      'subcategory': 'numerik',
    },
    'mechanicMode': 'focus',
    'reason': <String, dynamic>{
      'headline': 'Perkuat TIU Numerik',
      'description': 'Akurasi perlu diperbaiki.',
    },
    'confidence': 'medium',
    'availability': <String, dynamic>{
      'runnable': true,
      'compatibilityAdapter': 'practice_fixed_five',
      'label': 'Practice 5 soal (kompatibilitas)',
    },
  },
  'summary': <String, dynamic>{
    'curriculumCoverage': <String, dynamic>{
      'value': null,
      'coveredSkillCount': 0,
      'requiredSkillCount': 0,
      'confidence': 'low',
    },
    'unseenIndependentAccuracy': <String, dynamic>{
      'value': null,
      'correctCount': 0,
      'attemptCount': 0,
      'uniqueQuestionCount': 0,
      'confidence': 'low',
      'asOf': '2026-09-01T02:00:00.000Z',
    },
    'pace': <String, dynamic>{
      'value': null,
      'baselineType': null,
      'attemptCount': 0,
      'confidence': 'low',
    },
  },
  'skillStates': skillStates,
  'trends': <dynamic>[],
  'retention': <dynamic>[],
  'assessment': <String, dynamic>{'status': 'not_available'},
  'activity': <String, dynamic>{},
  'competition': <String, dynamic>{'accuracy': <String, dynamic>{}},
};
