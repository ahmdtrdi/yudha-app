import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

void main() {
  test('starts with three cards and lets the player choose one', () async {
    final repository = _FakeSoloRepository();
    final controller = SoloSessionController(repository);

    expect(
      await controller.start(
        count: SoloQuestionCount.twenty,
        characterId: 'character-basic-squire',
      ),
      isTrue,
    );
    expect(controller.state.session!.hand, hasLength(3));
    expect(repository.openCalls, 0);

    await controller.openCard(controller.state.session!.hand[1]);
    expect(repository.lastOpened, 'sq-2');
    expect(controller.state.openedQuestion!.questionOrder, 2);
    expect(controller.state.questionVisible, isTrue);
  });

  test('resumes an existing active session', () async {
    final repository = _FakeSoloRepository();
    final controller = SoloSessionController(repository);
    addTearDown(controller.dispose);

    expect(await controller.resume('solo-1'), isTrue);
    expect(repository.lastResumed, 'solo-1');
    expect(controller.state.session?.isActive, isTrue);
  });

  test('requests an authoritative hint and applies tower state', () async {
    final repository = _FakeSoloRepository();
    final controller = SoloSessionController(repository);
    addTearDown(controller.dispose);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    await controller.openCard(controller.state.session!.hand.first);
    await controller.showHint();
    await controller.selectAndSubmit(2);

    expect(repository.lastOption, 2);
    expect(repository.hintCalls, 1);
    expect(controller.state.openedQuestion!.hint, 'Petunjuk server.');
    expect(controller.state.showFeedback, isTrue);
    expect(controller.state.reaction, SoloReaction.idle);
    expect(controller.state.session!.towerHp, 95);

    controller.next();
    expect(controller.state.showFeedback, isFalse);
    expect(controller.state.reaction, SoloReaction.attack);
  });

  test('keeps answer and hint state while switching dealt cards', () async {
    final repository = _FakeSoloRepository();
    final controller = SoloSessionController(repository);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    final card = controller.state.session!.hand.first;
    await controller.openCard(card);
    await controller.showHint();
    controller.select(1);
    controller.closeQuestion();
    await controller.openCard(controller.state.session!.hand[1]);
    controller.closeQuestion();
    await controller.openCard(card);

    expect(controller.state.hintVisible, isTrue);
    expect(controller.state.selectedOption, 1);
  });

  test('a pending hint request does not trap the question sheet', () async {
    final Completer<SoloHint> hint = Completer<SoloHint>();
    final repository = _FakeSoloRepository(pendingHint: hint);
    final controller = SoloSessionController(repository);
    addTearDown(controller.dispose);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    await controller.openCard(controller.state.session!.hand.first);

    final Future<void> request = controller.showHint();
    expect(controller.state.hintLoading, isTrue);
    expect(controller.state.submitting, isFalse);
    controller.closeQuestion();
    expect(controller.state.questionVisible, isFalse);

    hint.complete(
      SoloHint(hint: 'Petunjuk server.', requestedAt: DateTime.now()),
    );
    await request;
    expect(controller.state.questionVisible, isFalse);
  });

  test(
    'can leave while an answer request finishes in the background',
    () async {
      final Completer<SoloAnswerResponse> answer =
          Completer<SoloAnswerResponse>();
      final repository = _FakeSoloRepository(pendingAnswer: answer);
      final controller = SoloSessionController(repository);
      addTearDown(controller.dispose);
      await controller.start(
        count: SoloQuestionCount.twenty,
        characterId: 'character-basic-squire',
      );
      await controller.openCard(controller.state.session!.hand.first);

      final Future<void> submission = controller.selectAndSubmit(2);
      expect(controller.state.submitting, isTrue);
      controller.closeQuestion();
      expect(controller.state.questionVisible, isFalse);

      answer.complete(repository.answerResponse());
      await submission;
      expect(controller.state.questionVisible, isFalse);
      expect(controller.state.showFeedback, isFalse);
      expect(controller.state.session!.answeredCount, 1);
    },
  );

  test('defers the wrong-answer hit reaction until continue', () async {
    final repository = _FakeSoloRepository(isCorrect: false);
    final controller = SoloSessionController(repository);
    addTearDown(controller.dispose);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    await controller.openCard(controller.state.session!.hand.first);
    await controller.selectAndSubmit(0);

    expect(controller.state.showFeedback, isTrue);
    expect(controller.state.reaction, SoloReaction.idle);

    controller.next();
    expect(controller.state.showFeedback, isFalse);
    expect(controller.state.reaction, SoloReaction.hit);
  });

  test(
    'keeps partial attempts but returns stopped result without reward',
    () async {
      final repository = _FakeSoloRepository();
      final controller = SoloSessionController(repository);
      await controller.start(
        count: SoloQuestionCount.twenty,
        characterId: 'character-basic-squire',
      );
      await controller.stop();

      expect(controller.state.session!.completionReason, 'user_stopped');
      expect(controller.state.session!.rewardCoins, 0);
    },
  );
}

class _FakeSoloRepository extends SoloRepository {
  _FakeSoloRepository({
    this.isCorrect = true,
    this.pendingHint,
    this.pendingAnswer,
  }) : super(accessToken: 'token');

  final bool isCorrect;
  final Completer<SoloHint>? pendingHint;
  final Completer<SoloAnswerResponse>? pendingAnswer;

  int openCalls = 0;
  String? lastOpened;
  String? lastResumed;
  int? lastOption;
  int hintCalls = 0;

  @override
  Future<SoloSession> create({
    required SoloQuestionCount questionCount,
    required String characterId,
  }) async => _session();

  @override
  Future<SoloQuestion> open(String sessionId, String questionId) async {
    openCalls += 1;
    lastOpened = questionId;
    final order = int.parse(questionId.split('-').last);
    return _question(order);
  }

  @override
  Future<SoloSession> get(String sessionId) async {
    lastResumed = sessionId;
    return _session();
  }

  @override
  Future<SoloHint> requestHint(String sessionId, String questionId) async {
    hintCalls += 1;
    if (pendingHint != null) return pendingHint!.future;
    return SoloHint(hint: 'Petunjuk server.', requestedAt: DateTime.now());
  }

  @override
  Future<SoloAnswerResponse> answer(
    String sessionId,
    String questionId,
    int? optionIndex, {
    int? clientActiveResponseTimeMs,
    int? backgroundDurationMs,
  }) async {
    lastOption = optionIndex;
    if (pendingAnswer != null) return pendingAnswer!.future;
    return answerResponse();
  }

  SoloAnswerResponse answerResponse() => SoloAnswerResponse(
    session: _session(
      answeredCount: 1,
      correctCount: isCorrect ? 1 : 0,
      towerHp: isCorrect ? 95 : 100,
    ),
    feedback: SoloAnswerFeedback(
      sessionQuestionId: 'sq-1',
      isCorrect: isCorrect,
      timedOut: false,
      correctOptionIndex: 2,
      explanation: 'Pembahasan.',
    ),
  );

  @override
  Future<SoloSession> stop(String sessionId) async =>
      _session(status: 'stopped', completionReason: 'user_stopped');
}

SoloQuestion _question(int order) {
  final now = DateTime.now();
  return SoloQuestion(
    sessionQuestionId: 'sq-$order',
    questionOrder: order,
    category: order == 1 ? 'twk' : 'tiu',
    prompt: 'Pertanyaan $order?',
    options: const <String>['A', 'B', 'C', 'D'],
    timeLimitSeconds: 30,
    openedAt: now,
    deadlineAt: now.add(const Duration(seconds: 30)),
  );
}

SoloSession _session({
  int answeredCount = 0,
  int correctCount = 0,
  int towerHp = 100,
  String status = 'active',
  String? completionReason,
  String? policyStopTrigger,
}) => SoloSession(
  id: 'solo-1',
  target: 'cpns',
  questionCount: 20,
  characterId: 'character-basic-squire',
  status: status,
  completionReason: completionReason,
  policyStopTrigger: policyStopTrigger,
  answeredCount: answeredCount,
  correctCount: correctCount,
  towerHp: towerHp,
  rewardCoins: 0,
  hand: status == 'active'
      ? <SoloHandCard>[
          for (
            int order = answeredCount + 1;
            order <= answeredCount + 3;
            order++
          )
            SoloHandCard(
              sessionQuestionId: 'sq-$order',
              questionOrder: order,
              category: order.isOdd ? 'twk' : 'tiu',
              subcategory: order.isOdd ? 'twk' : 'logika',
            ),
        ]
      : const <SoloHandCard>[],
);
