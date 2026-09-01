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

  test('submits hint use and applies authoritative tower state', () async {
    final repository = _FakeSoloRepository();
    final controller = SoloSessionController(repository);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    await controller.openCard(controller.state.session!.hand.first);
    controller.showHint();
    await controller.selectAndSubmit(2);

    expect(repository.lastOption, 2);
    expect(repository.lastUsedHint, isTrue);
    expect(controller.state.showFeedback, isTrue);
    expect(controller.state.reaction, SoloReaction.attack);
    expect(controller.state.session!.towerHp, 95);
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
    controller.showHint();
    controller.select(1);
    controller.closeQuestion();
    await controller.openCard(controller.state.session!.hand[1]);
    controller.closeQuestion();
    await controller.openCard(card);

    expect(controller.state.hintVisible, isTrue);
    expect(controller.state.selectedOption, 1);
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
  _FakeSoloRepository() : super(accessToken: 'token');

  int openCalls = 0;
  String? lastOpened;
  int? lastOption;
  bool? lastUsedHint;

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
  Future<SoloAnswerResponse> answer(
    String sessionId,
    String questionId,
    int? optionIndex,
    bool usedHint,
  ) async {
    lastOption = optionIndex;
    lastUsedHint = usedHint;
    return SoloAnswerResponse(
      session: _session(answeredCount: 1, correctCount: 1, towerHp: 95),
      feedback: const SoloAnswerFeedback(
        sessionQuestionId: 'sq-1',
        isCorrect: true,
        timedOut: false,
        correctOptionIndex: 2,
        explanation: 'Pembahasan.',
      ),
    );
  }

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
    hint: 'Petunjuk.',
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
}) => SoloSession(
  id: 'solo-1',
  target: 'cpns',
  questionCount: 20,
  characterId: 'character-basic-squire',
  status: status,
  completionReason: completionReason,
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
