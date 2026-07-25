class BattleAnswerRecord {
  const BattleAnswerRecord({
    required this.questionId,
    required this.prompt,
    required this.category,
    required this.isCorrect,
  });

  final String questionId;
  final String prompt;
  final String category;
  final bool isCorrect;
}
