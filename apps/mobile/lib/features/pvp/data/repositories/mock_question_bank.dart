import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';

abstract final class MockQuestionBank {
  static const String _assetPath = 'assets/game/questions.json';

  static Future<List<BattleQuestion>> loadBattleQuestions() async {
    try {
      final String rawJson = await rootBundle.loadString(_assetPath);
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        return sample();
      }

      final List<BattleQuestion> questions = decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);

      return _buildBattleOrder(questions);
    } catch (_) {
      return sample();
    }
  }

  static List<BattleQuestion> sample() {
    return const <BattleQuestion>[
      BattleQuestion(
        id: 'twk-1',
        prompt: 'Dasar negara Indonesia adalah...',
        options: <String>[
          'UUD 1945',
          'Pancasila',
          'Bhinneka Tunggal Ika',
          'NKRI',
        ],
        correctOptionIndex: 1,
        weight: 1,
        effect: QuestionEffect.heal,
        category: 'twk',
      ),
      BattleQuestion(
        id: 'tiu-1',
        prompt: 'Jika 6 x 7 = ?',
        options: <String>['40', '42', '48', '36'],
        correctOptionIndex: 1,
        weight: 2,
        effect: QuestionEffect.damage,
        category: 'numerik',
      ),
      BattleQuestion(
        id: 'verbal-1',
        prompt: 'Sinonim dari akurat adalah...',
        options: <String>['Cepat', 'Tepat', 'Samar', 'Lambat'],
        correctOptionIndex: 1,
        weight: 1,
        effect: QuestionEffect.damage,
        category: 'verbal',
      ),
      BattleQuestion(
        id: 'logika-1',
        prompt: 'Deret 2, 4, 8, 16, ...',
        options: <String>['18', '20', '24', '32'],
        correctOptionIndex: 3,
        weight: 3,
        effect: QuestionEffect.damage,
        category: 'logika',
      ),
      BattleQuestion(
        id: 'twk-2',
        prompt: 'Semboyan Bhinneka Tunggal Ika bermakna...',
        options: <String>[
          'Berbeda-beda tetap satu',
          'Satu bangsa satu budaya',
          'Persatuan dengan paksaan',
          'Kesamaan pendapat',
        ],
        correctOptionIndex: 0,
        weight: 2,
        effect: QuestionEffect.heal,
        category: 'twk',
      ),
    ];
  }

  static BattleQuestion _fromJson(Map<String, dynamic> json) {
    final String category = (json['tipe'] as String? ?? 'numerik')
        .trim()
        .toLowerCase();
    final Map<String, dynamic> rawOptions =
        json['option'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final List<String> options = <String>[
      rawOptions['a']?.toString() ?? '',
      rawOptions['b']?.toString() ?? '',
      rawOptions['c']?.toString() ?? '',
      rawOptions['d']?.toString() ?? '',
    ];
    final String correctAnswer = (json['correct_answer'] as String? ?? 'a')
        .toLowerCase();
    final int correctIndex = switch (correctAnswer) {
      'b' => 1,
      'c' => 2,
      'd' => 3,
      _ => 0,
    };

    return BattleQuestion(
      id: '$category-${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      prompt: json['question']?.toString() ?? '',
      options: options,
      correctOptionIndex: correctIndex,
      weight: (json['point_kesulitan'] as num?)?.round() ?? 1,
      effect: category == 'twk' ? QuestionEffect.heal : QuestionEffect.damage,
      category: category,
    );
  }

  static List<BattleQuestion> _buildBattleOrder(
    List<BattleQuestion> questions,
  ) {
    if (questions.isEmpty) {
      return sample();
    }

    final Map<String, List<BattleQuestion>> groups =
        <String, List<BattleQuestion>>{};
    for (final BattleQuestion question in questions) {
      groups.putIfAbsent(question.category, () => <BattleQuestion>[]).add(
        question,
      );
    }

    final Random random = Random();
    for (final List<BattleQuestion> group in groups.values) {
      group.shuffle(random);
    }

    const List<String> categoryLoop = <String>[
      'numerik',
      'twk',
      'verbal',
      'logika',
      'twk',
      'numerik',
      'verbal',
      'logika',
    ];
    final List<BattleQuestion> ordered = <BattleQuestion>[];
    int cursor = 0;

    while (ordered.length < 24 && groups.values.any((group) => group.isNotEmpty)) {
      final String category = categoryLoop[cursor % categoryLoop.length];
      final List<BattleQuestion>? group = groups[category];
      if (group != null && group.isNotEmpty) {
        ordered.add(group.removeLast());
      }
      cursor++;
      if (cursor > 500) {
        break;
      }
    }

    return ordered.isEmpty ? sample() : ordered;
  }
}
