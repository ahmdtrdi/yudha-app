import 'package:yudha_mobile/features/pvp/domain/entities/battle_answer_record.dart';

class BattleCategoryPerformance {
  const BattleCategoryPerformance({
    required this.category,
    required this.totalAnswers,
    required this.correctAnswers,
  });

  final String category;
  final int totalAnswers;
  final int correctAnswers;

  int get incorrectAnswers => totalAnswers - correctAnswers;

  int get accuracyPercent {
    if (totalAnswers == 0) {
      return 0;
    }
    return ((correctAnswers / totalAnswers) * 100).round();
  }
}

class BattleMissedCard {
  const BattleMissedCard({
    required this.prompt,
    required this.category,
    required this.incorrectAnswers,
    required this.totalAnswers,
  });

  final String prompt;
  final String category;
  final int incorrectAnswers;
  final int totalAnswers;
}

class BattlePerformanceInsight {
  const BattlePerformanceInsight({
    required this.weakestCategory,
    this.mostMissedCard,
  });

  final BattleCategoryPerformance weakestCategory;
  final BattleMissedCard? mostMissedCard;
}

abstract final class BattlePerformanceAnalyzer {
  static BattlePerformanceInsight? analyze(List<BattleAnswerRecord> answers) {
    if (answers.isEmpty) {
      return null;
    }

    final Map<String, _MutableCategoryPerformance> categories =
        <String, _MutableCategoryPerformance>{};
    final Map<String, _MutableMissedCard> missedCards =
        <String, _MutableMissedCard>{};

    for (final BattleAnswerRecord answer in answers) {
      final String normalizedCategory = _normalize(answer.category);
      final _MutableCategoryPerformance category = categories.putIfAbsent(
        normalizedCategory,
        () => _MutableCategoryPerformance(answer.category.trim()),
      );
      category.totalAnswers += 1;
      if (answer.isCorrect) {
        category.correctAnswers += 1;
      }

      final String prompt = answer.prompt.trim();
      if (prompt.isEmpty) {
        continue;
      }
      final String cardKey = '$normalizedCategory::${_normalize(prompt)}';
      final _MutableMissedCard card = missedCards.putIfAbsent(
        cardKey,
        () => _MutableMissedCard(
          prompt: prompt,
          category: answer.category.trim(),
        ),
      );
      card.totalAnswers += 1;
      if (!answer.isCorrect) {
        card.incorrectAnswers += 1;
      }
    }

    final List<BattleCategoryPerformance> rankedCategories =
        categories.values
            .map(
              (_MutableCategoryPerformance item) => BattleCategoryPerformance(
                category: item.category,
                totalAnswers: item.totalAnswers,
                correctAnswers: item.correctAnswers,
              ),
            )
            .toList(growable: false)
          ..sort(_compareCategories);
    final List<BattleMissedCard> rankedCards =
        missedCards.values
            .where((_MutableMissedCard item) => item.incorrectAnswers > 0)
            .map(
              (_MutableMissedCard item) => BattleMissedCard(
                prompt: item.prompt,
                category: item.category,
                incorrectAnswers: item.incorrectAnswers,
                totalAnswers: item.totalAnswers,
              ),
            )
            .toList(growable: false)
          ..sort(_compareCards);

    return BattlePerformanceInsight(
      weakestCategory: rankedCategories.first,
      mostMissedCard: rankedCards.firstOrNull,
    );
  }

  static int _compareCategories(
    BattleCategoryPerformance left,
    BattleCategoryPerformance right,
  ) {
    final int accuracyComparison = (left.correctAnswers * right.totalAnswers)
        .compareTo(right.correctAnswers * left.totalAnswers);
    if (accuracyComparison != 0) {
      return accuracyComparison;
    }
    final int mistakesComparison = right.incorrectAnswers.compareTo(
      left.incorrectAnswers,
    );
    if (mistakesComparison != 0) {
      return mistakesComparison;
    }
    final int correctComparison = left.correctAnswers.compareTo(
      right.correctAnswers,
    );
    if (correctComparison != 0) {
      return correctComparison;
    }
    return _normalize(left.category).compareTo(_normalize(right.category));
  }

  static int _compareCards(BattleMissedCard left, BattleMissedCard right) {
    final int mistakesComparison = right.incorrectAnswers.compareTo(
      left.incorrectAnswers,
    );
    if (mistakesComparison != 0) {
      return mistakesComparison;
    }
    final int attemptsComparison = right.totalAnswers.compareTo(
      left.totalAnswers,
    );
    if (attemptsComparison != 0) {
      return attemptsComparison;
    }
    return _normalize(left.prompt).compareTo(_normalize(right.prompt));
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}

class _MutableCategoryPerformance {
  _MutableCategoryPerformance(this.category);

  final String category;
  int totalAnswers = 0;
  int correctAnswers = 0;
}

class _MutableMissedCard {
  _MutableMissedCard({required this.prompt, required this.category});

  final String prompt;
  final String category;
  int incorrectAnswers = 0;
  int totalAnswers = 0;
}
