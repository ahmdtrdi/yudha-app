import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

void main() {
  test(
    'starts, opens, and applies authoritative correct-answer tower state',
    () async {
      final repository = _FakeSoloRepository();
      repository.createResult = _session(opened: false);
      repository.getResult = _session(opened: true);
      repository.answerResult = _session(
        opened: true,
        answeredCount: 1,
        correctCount: 1,
        towerHp: 95,
        firstCorrect: true,
      );
      final controller = SoloSessionController(repository);

      expect(
        await controller.start(
          count: SoloQuestionCount.twenty,
          characterId: 'character-basic-squire',
        ),
        isTrue,
      );
      expect(repository.openCalls, 1);

      controller.select(2);
      await controller.submit();

      expect(controller.state.showFeedback, isTrue);
      expect(controller.state.reaction, SoloReaction.attack);
      expect(controller.state.session!.towerHp, 95);
      expect(repository.lastOption, 2);
    },
  );

  test(
    'reconciles elapsed Standard deadline as timeout and hit reaction',
    () async {
      final repository = _FakeSoloRepository();
      repository.createResult = _session(opened: true, deadlineInPast: true);
      repository.answerResult = _session(
        opened: true,
        answeredCount: 1,
        towerHp: 100,
        firstCorrect: false,
        firstTimedOut: true,
      );
      final controller = SoloSessionController(repository);

      await controller.start(
        count: SoloQuestionCount.twenty,
        characterId: 'character-basic-squire',
      );
      await controller.timeout();

      expect(repository.lastOption, isNull);
      expect(controller.state.reaction, SoloReaction.hit);
      expect(controller.state.session!.towerHp, 100);
    },
  );

  test(
    'keeps partial attempts but returns stopped result without reward',
    () async {
      final repository = _FakeSoloRepository();
      repository.createResult = _session(opened: true);
      repository.stopResult = _session(
        opened: true,
        status: 'stopped',
        completionReason: 'user_stopped',
      );
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

  late SoloSession createResult;
  late SoloSession answerResult;
  late SoloSession stopResult;
  SoloSession? getResult;
  int openCalls = 0;
  int? lastOption;

  @override
  Future<SoloSession> create({
    required SoloQuestionCount questionCount,
    required String characterId,
  }) async => createResult;

  @override
  Future<SoloSession> get(String sessionId) async => getResult ?? createResult;

  @override
  Future<Map<String, dynamic>> open(String sessionId, String questionId) async {
    openCalls += 1;
    return const <String, dynamic>{};
  }

  @override
  Future<SoloSession> answer(
    String sessionId,
    String questionId,
    int? optionIndex,
  ) async {
    lastOption = optionIndex;
    return answerResult;
  }

  @override
  Future<SoloSession> stop(String sessionId) async => stopResult;
}

SoloSession _session({
  bool opened = true,
  bool deadlineInPast = false,
  int answeredCount = 0,
  int correctCount = 0,
  int towerHp = 100,
  bool? firstCorrect,
  bool firstTimedOut = false,
  String status = 'active',
  String? completionReason,
}) {
  final now = DateTime.now();
  return SoloSession(
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
    questions: <SoloQuestion>[
      SoloQuestion(
        sessionQuestionId: 'sq-1',
        questionOrder: 1,
        category: 'twk',
        prompt: 'Pertanyaan pertama?',
        options: const <String>['A', 'B', 'C', 'D'],
        timeLimitSeconds: 30,
        openedAt: opened ? now.subtract(const Duration(seconds: 2)) : null,
        deadlineAt: opened
            ? deadlineInPast
                  ? now.subtract(const Duration(seconds: 1))
                  : now.add(const Duration(seconds: 28))
            : null,
        answered: answeredCount > 0,
        selectedOptionIndex: firstTimedOut
            ? null
            : (answeredCount > 0 ? 2 : null),
        isCorrect: firstCorrect,
        timedOut: firstTimedOut,
        correctOptionIndex: answeredCount > 0 ? 2 : null,
        explanation: answeredCount > 0 ? 'Pembahasan.' : null,
      ),
      SoloQuestion(
        sessionQuestionId: 'sq-2',
        questionOrder: 2,
        category: 'tiu',
        prompt: 'Pertanyaan kedua?',
        options: const <String>['A', 'B', 'C', 'D'],
        timeLimitSeconds: 30,
      ),
    ],
  );
}
