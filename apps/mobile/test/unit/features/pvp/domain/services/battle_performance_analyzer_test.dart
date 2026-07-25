import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_answer_record.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_performance_analyzer.dart';

void main() {
  group('BattlePerformanceAnalyzer', () {
    test('finds the lowest-accuracy category and most-missed card', () {
      const List<BattleAnswerRecord> answers = <BattleAnswerRecord>[
        BattleAnswerRecord(
          questionId: 'n-1',
          prompt: 'Dua tambah dua?',
          category: 'numerik',
          isCorrect: false,
        ),
        BattleAnswerRecord(
          questionId: 'n-1-recycled',
          prompt: 'Dua tambah dua?',
          category: 'numerik',
          isCorrect: false,
        ),
        BattleAnswerRecord(
          questionId: 'n-2',
          prompt: 'Tiga tambah tiga?',
          category: 'numerik',
          isCorrect: true,
        ),
        BattleAnswerRecord(
          questionId: 'v-1',
          prompt: 'Sinonim cepat?',
          category: 'verbal',
          isCorrect: true,
        ),
        BattleAnswerRecord(
          questionId: 'v-2',
          prompt: 'Antonim tinggi?',
          category: 'verbal',
          isCorrect: true,
        ),
      ];

      final BattlePerformanceInsight? insight =
          BattlePerformanceAnalyzer.analyze(answers);

      expect(insight, isNotNull);
      expect(insight!.weakestCategory.category, 'numerik');
      expect(insight.weakestCategory.correctAnswers, 1);
      expect(insight.weakestCategory.totalAnswers, 3);
      expect(insight.weakestCategory.accuracyPercent, 33);
      expect(insight.mostMissedCard?.prompt, 'Dua tambah dua?');
      expect(insight.mostMissedCard?.incorrectAnswers, 2);
      expect(insight.mostMissedCard?.totalAnswers, 2);
    });

    test('uses mistake count to break equal-accuracy ties', () {
      const List<BattleAnswerRecord> answers = <BattleAnswerRecord>[
        BattleAnswerRecord(
          questionId: 'l-1',
          prompt: 'Logika satu',
          category: 'logika',
          isCorrect: false,
        ),
        BattleAnswerRecord(
          questionId: 'l-2',
          prompt: 'Logika dua',
          category: 'logika',
          isCorrect: false,
        ),
        BattleAnswerRecord(
          questionId: 't-1',
          prompt: 'TWK satu',
          category: 'twk',
          isCorrect: false,
        ),
      ];

      final BattlePerformanceInsight? insight =
          BattlePerformanceAnalyzer.analyze(answers);

      expect(insight?.weakestCategory.category, 'logika');
    });

    test('returns no insight before the player answers a card', () {
      expect(
        BattlePerformanceAnalyzer.analyze(const <BattleAnswerRecord>[]),
        isNull,
      );
    });
  });
}
