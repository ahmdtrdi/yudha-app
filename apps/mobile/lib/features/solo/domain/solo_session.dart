class SoloQuestion {
  const SoloQuestion({
    required this.sessionQuestionId,
    required this.questionOrder,
    required this.category,
    required this.prompt,
    required this.options,
    required this.timeLimitSeconds,
    this.openedAt,
    this.deadlineAt,
    this.answered = false,
    this.selectedOptionIndex,
    this.isCorrect,
    this.timedOut = false,
    this.correctOptionIndex,
    this.explanation,
  });

  final String sessionQuestionId;
  final int questionOrder;
  final String category;
  final String prompt;
  final List<String> options;
  final int timeLimitSeconds;
  final DateTime? openedAt;
  final DateTime? deadlineAt;
  final bool answered;
  final int? selectedOptionIndex;
  final bool? isCorrect;
  final bool timedOut;
  final int? correctOptionIndex;
  final String? explanation;

  factory SoloQuestion.fromJson(Map<String, dynamic> json) => SoloQuestion(
    sessionQuestionId: json['sessionQuestionId']?.toString() ?? '',
    questionOrder: _int(json['questionOrder']),
    category: json['category']?.toString() ?? '',
    prompt: json['prompt']?.toString() ?? '',
    options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic option) => option is Map<String, dynamic>
              ? option['label']?.toString() ?? ''
              : option.toString(),
        )
        .toList(growable: false),
    timeLimitSeconds: _int(json['timeLimitSeconds']),
    openedAt: _date(json['openedAt']),
    deadlineAt: _date(json['deadlineAt']),
    answered: json['answered'] == true,
    selectedOptionIndex: _nullableInt(json['selectedOptionIndex']),
    isCorrect: json['isCorrect'] as bool?,
    timedOut: json['timedOut'] == true,
    correctOptionIndex: _nullableInt(json['correctOptionIndex']),
    explanation: json['explanation']?.toString(),
  );
}

class SoloSession {
  const SoloSession({
    required this.id,
    required this.target,
    required this.questionCount,
    required this.characterId,
    required this.status,
    required this.answeredCount,
    required this.correctCount,
    required this.towerHp,
    required this.rewardCoins,
    required this.questions,
    this.completionReason,
  });

  final String id;
  final String target;
  final int questionCount;
  final String characterId;
  final String status;
  final String? completionReason;
  final int answeredCount;
  final int correctCount;
  final int towerHp;
  final int rewardCoins;
  final List<SoloQuestion> questions;

  bool get isActive => status == 'active';
  SoloQuestion? get currentQuestion =>
      isActive && answeredCount < questions.length
      ? questions[answeredCount]
      : null;

  factory SoloSession.fromJson(Map<String, dynamic> json) => SoloSession(
    id: json['sessionId']?.toString() ?? '',
    target: json['target']?.toString() ?? '',
    questionCount: _int(json['questionCount']),
    characterId: json['characterId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
    completionReason: json['completionReason']?.toString(),
    answeredCount: _int(json['answeredCount']),
    correctCount: _int(json['correctCount']),
    towerHp: _int(json['towerHp']),
    rewardCoins: _int(json['rewardCoins']),
    questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SoloQuestion.fromJson)
        .toList(growable: false),
  );
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int? _nullableInt(Object? value) => value == null ? null : _int(value);
DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
