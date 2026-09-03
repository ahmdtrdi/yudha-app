import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

void main() {
  test(
    'preserves unavailable metrics as null and parses confidence metadata',
    () {
      final LearningDashboard dashboard = LearningDashboard.fromJson(
        _dashboardJson(),
      );

      expect(dashboard.accuracy.value, isNull);
      expect(dashboard.accuracy.attemptCount, 0);
      expect(dashboard.accuracy.confidence, 'low');
      expect(dashboard.pace.value, isNull);
      expect(dashboard.skillStates.single.category, 'tiu');
      expect(dashboard.skillStates.single.assistedAccuracy.value, 80);
      expect(dashboard.skillStates.single.medianResponseTimeMs, 32000);
      expect(dashboard.skillStates.single.paceBaselineType, 'personal');
      expect(dashboard.skillStates.single.timeoutRate, 10);
      expect(dashboard.skillStates.single.coverageSufficient, isTrue);
      expect(dashboard.retention.single.correctCount, 3);
      expect(dashboard.retention.single.confidence, 'low');
      expect(dashboard.assessment.status, 'validated');
      expect(dashboard.assessment.correctCount, 84);
      expect(dashboard.assessment.confidence, 'high');
      expect(dashboard.assessment.baseline?.score, 76);
      expect(dashboard.assessment.latest?.score, 84);
      expect(dashboard.nextAction?.skillLabel, 'TIU Numerik');
      expect(dashboard.nextAction?.runnable, isTrue);
      expect(dashboard.activity.weeklyActivity.single.questionsAnswered, 12);
      expect(dashboard.activity.recentSessions.single.skillLabels, <String>[
        'TIU Numerik',
      ]);
      expect(dashboard.assessment.improvementPercentagePoints, 8);
      expect(dashboard.assessment.categoryBreakdown.single.correctCount, 43);
      expect(dashboard.assessment.categoryBreakdown.single.confidence, 'high');
      expect(dashboard.competition.tier, 'warrior');
      expect(dashboard.competition.accuracy.confidence, 'medium');
    },
  );

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
  List<Map<String, dynamic>> skillStates = const <Map<String, dynamic>>[
    <String, dynamic>{
      'skillId': 'cpns.tiu.numerik',
      'label': 'TIU Numerik',
      'category': 'tiu',
      'subcategory': 'numerik',
      'required': true,
      'status': 'developing',
      'evidenceConfidence': 'medium',
      'unseenIndependentAccuracy': <String, dynamic>{
        'value': 70,
        'correctCount': 7,
        'attemptCount': 10,
        'uniqueQuestionCount': 8,
        'confidence': 'medium',
      },
      'assistedAccuracy': <String, dynamic>{
        'value': 80,
        'correctCount': 4,
        'attemptCount': 5,
        'uniqueQuestionCount': 4,
        'confidence': 'medium',
      },
      'medianResponseTimeMs': 32000,
      'paceRatio': 1.1,
      'paceBaselineType': 'personal',
      'paceAttemptCount': 10,
      'timeoutRate': 10,
      'coverageSufficient': true,
      'recommendedMechanic': 'standard',
    },
  ],
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
  'retention': <Map<String, dynamic>>[
    <String, dynamic>{
      'skillId': 'cpns.tiu.numerik',
      'label': 'TIU Numerik',
      'status': 'due',
      'reviewDueAt': '2026-09-01T02:00:00.000Z',
      'accuracy': 75,
      'correctCount': 3,
      'attemptCount': 4,
      'confidence': 'low',
      'asOf': '2026-09-01T02:00:00.000Z',
    },
  ],
  'assessment': <String, dynamic>{
    'status': 'validated',
    'score': 84,
    'correctCount': 84,
    'attemptCount': 100,
    'confidence': 'high',
    'asOf': '2026-09-01T02:00:00.000Z',
    'improvementPercentagePoints': 8,
    'categoryBreakdown': <Map<String, dynamic>>[
      <String, dynamic>{
        'category': 'tiu',
        'label': 'TIU',
        'score': 86,
        'correctCount': 43,
        'attemptCount': 50,
        'confidence': 'high',
        'asOf': '2026-09-01T02:00:00.000Z',
      },
    ],
    'baseline': <String, dynamic>{
      'score': 76,
      'attemptCount': 100,
      'blueprintVersion': 'cpns-1',
    },
    'latest': <String, dynamic>{
      'score': 84,
      'attemptCount': 100,
      'blueprintVersion': 'cpns-1',
    },
  },
  'activity': <String, dynamic>{
    'streak': <String, dynamic>{'current': 3, 'best': 7},
    'weeklyActivity': <Map<String, dynamic>>[
      <String, dynamic>{
        'startsOn': '2026-08-26',
        'endsOn': '2026-09-01',
        'questionsAnswered': 12,
        'sessionCount': 2,
      },
    ],
    'recentSessions': <Map<String, dynamic>>[
      <String, dynamic>{
        'sessionKey': 'session-1',
        'lastActivityAt': '2026-09-01T02:00:00.000Z',
        'completionState': 'compatibility_completed',
        'skillLabels': <String>['TIU Numerik'],
        'correctCount': 4,
        'attemptCount': 5,
        'accuracy': 80,
      },
    ],
  },
  'competition': <String, dynamic>{
    'accuracy': <String, dynamic>{
      'value': 80,
      'correctCount': 4,
      'attemptCount': 5,
      'uniqueQuestionCount': 5,
      'confidence': 'medium',
      'asOf': '2026-09-01T02:00:00.000Z',
    },
    'rankPoints': 430,
    'tier': 'warrior',
    'matchRecord': <String, dynamic>{
      'wins': 4,
      'losses': 3,
      'draws': 1,
      'totalMatches': 8,
      'winRate': 50,
    },
  },
};
