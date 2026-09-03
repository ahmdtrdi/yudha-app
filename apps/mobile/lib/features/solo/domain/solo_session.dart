import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloHandCard {
  const SoloHandCard({
    required this.sessionQuestionId,
    required this.questionOrder,
    required this.category,
    required this.subcategory,
    this.openedAt,
    this.deadlineAt,
  });

  final String sessionQuestionId;
  final int questionOrder;
  final String category;
  final String subcategory;
  final DateTime? openedAt;
  final DateTime? deadlineAt;

  factory SoloHandCard.fromJson(Map<String, dynamic> json) => SoloHandCard(
    sessionQuestionId: json['sessionQuestionId']?.toString() ?? '',
    questionOrder: _int(json['questionOrder']),
    category: json['category']?.toString() ?? '',
    subcategory: json['subcategory']?.toString() ?? '',
    openedAt: _date(json['openedAt']),
    deadlineAt: _date(json['deadlineAt']),
  );
}

class SoloQuestion {
  const SoloQuestion({
    required this.sessionQuestionId,
    required this.questionOrder,
    required this.category,
    required this.prompt,
    required this.options,
    required this.timeLimitSeconds,
    this.hint = '',
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
  final String hint;
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
    hint: json['hint']?.toString() ?? '',
    openedAt: _date(json['openedAt']),
    deadlineAt: _date(json['deadlineAt']),
    answered: json['answered'] == true,
    selectedOptionIndex: _nullableInt(json['selectedOptionIndex']),
    isCorrect: json['isCorrect'] as bool?,
    timedOut: json['timedOut'] == true,
    correctOptionIndex: _nullableInt(json['correctOptionIndex']),
    explanation: json['explanation']?.toString(),
  );

  SoloQuestion copyWith({
    String? sessionQuestionId,
    int? questionOrder,
    String? category,
    String? prompt,
    List<String>? options,
    int? timeLimitSeconds,
    String? hint,
    DateTime? openedAt,
    DateTime? deadlineAt,
    bool clearDeadline = false,
    bool? answered,
    int? selectedOptionIndex,
    bool? isCorrect,
    bool? timedOut,
    int? correctOptionIndex,
    String? explanation,
  }) => SoloQuestion(
    sessionQuestionId: sessionQuestionId ?? this.sessionQuestionId,
    questionOrder: questionOrder ?? this.questionOrder,
    category: category ?? this.category,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
    hint: hint ?? this.hint,
    openedAt: openedAt ?? this.openedAt,
    deadlineAt: clearDeadline ? null : deadlineAt ?? this.deadlineAt,
    answered: answered ?? this.answered,
    selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
    isCorrect: isCorrect ?? this.isCorrect,
    timedOut: timedOut ?? this.timedOut,
    correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
    explanation: explanation ?? this.explanation,
  );

  SoloQuestion withHint(String value) => SoloQuestion(
    sessionQuestionId: sessionQuestionId,
    questionOrder: questionOrder,
    category: category,
    prompt: prompt,
    options: options,
    timeLimitSeconds: timeLimitSeconds,
    hint: value,
    openedAt: openedAt,
    deadlineAt: deadlineAt,
    answered: answered,
    selectedOptionIndex: selectedOptionIndex,
    isCorrect: isCorrect,
    timedOut: timedOut,
    correctOptionIndex: correctOptionIndex,
    explanation: explanation,
  );
}

class SoloHint {
  const SoloHint({required this.hint, required this.requestedAt});

  final String hint;
  final DateTime? requestedAt;

  factory SoloHint.fromJson(Map<String, dynamic> json) => SoloHint(
    hint: json['hint']?.toString() ?? '',
    requestedAt: _date(json['requestedAt'] ?? json['hintRequestedAt']),
  );
}

class SoloAnswerFeedback {
  const SoloAnswerFeedback({
    required this.sessionQuestionId,
    required this.isCorrect,
    required this.timedOut,
    required this.correctOptionIndex,
    required this.explanation,
    this.attemptId,
  });

  final String sessionQuestionId;
  final bool isCorrect;
  final bool timedOut;
  final int correctOptionIndex;
  final String explanation;
  final String? attemptId;

  factory SoloAnswerFeedback.fromJson(Map<String, dynamic> json) =>
      SoloAnswerFeedback(
        sessionQuestionId: json['sessionQuestionId']?.toString() ?? '',
        isCorrect: json['isCorrect'] == true,
        timedOut: json['timedOut'] == true,
        correctOptionIndex: _int(json['correctOptionIndex']),
        explanation: json['explanation']?.toString() ?? '',
        attemptId: json['attemptId']?.toString(),
      );
}

class SoloAnswerResponse {
  const SoloAnswerResponse({required this.session, required this.feedback});
  final SoloSession session;
  final SoloAnswerFeedback feedback;

  factory SoloAnswerResponse.fromJson(Map<String, dynamic> json) =>
      SoloAnswerResponse(
        session: SoloSession.fromJson(json),
        feedback: SoloAnswerFeedback.fromJson(
          json['answerResult'] as Map<String, dynamic>? ??
              const <String, dynamic>{},
        ),
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
    required this.hand,
    this.completionReason,
    this.policyStopTrigger,
    this.mechanicMode = SoloMechanicMode.standard,
  });

  final String id;
  final String target;
  final int questionCount;
  final String characterId;
  final String status;
  final String? completionReason;
  final String? policyStopTrigger;
  final int answeredCount;
  final int correctCount;
  final int towerHp;
  final int rewardCoins;
  final List<SoloHandCard> hand;
  final SoloMechanicMode mechanicMode;

  bool get isActive => status == 'active';

  factory SoloSession.fromJson(Map<String, dynamic> json) => SoloSession(
    id: json['sessionId']?.toString() ?? '',
    target: json['target']?.toString() ?? '',
    questionCount: _int(json['questionCount']),
    characterId: json['characterId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
    completionReason: json['completionReason']?.toString(),
    policyStopTrigger: json['policyStopTrigger']?.toString(),
    answeredCount: _int(json['answeredCount']),
    correctCount: _int(json['correctCount']),
    towerHp: _int(json['towerHp']),
    rewardCoins: _int(json['rewardCoins']),
    hand: (json['hand'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SoloHandCard.fromJson)
        .toList(growable: false),
    mechanicMode: SoloMechanicMode.parse(
      json['mechanicMode'] ?? json['effectiveMechanicMode'] ?? 'standard',
    ),
  );
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int? _nullableInt(Object? value) => value == null ? null : _int(value);
DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
