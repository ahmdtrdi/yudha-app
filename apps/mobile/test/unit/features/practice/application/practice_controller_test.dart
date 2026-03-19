import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/practice/application/practice_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/mock_practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';

void main() {
  test('load initializes topics and first topic session', () async {
    final PracticeController controller = PracticeController(
      repository: const MockPracticeRepository(),
    );

    await controller.reload();

    expect(controller.state.status, PracticeViewStatus.ready);
    expect(controller.state.topics, isNotEmpty);
    expect(controller.state.questions, isNotEmpty);
    expect(controller.state.currentQuestionIndex, 0);
    expect(controller.state.questionOfDay, isNotNull);
  });

  test('submit answer on question of day can complete session', () async {
    final PracticeController controller = PracticeController(
      repository: const MockPracticeRepository(),
    );

    await controller.reload();
    controller.startQuestionOfDay();

    final question = controller.state.currentQuestion;
    expect(question, isNotNull);
    controller.selectOption(question!.correctOption!.id);
    controller.submitCurrentAnswer();

    expect(controller.state.status, PracticeViewStatus.completed);
    expect(controller.state.correctAnswers, 1);
    expect(controller.state.isCurrentQuestionSubmitted, isTrue);
  });

  test('hint flow transitions through watch ad and buy states', () async {
    final PracticeController controller = PracticeController(
      repository: const MockPracticeRepository(),
    );

    await controller.reload();

    expect(controller.state.hintState, PracticeHintState.locked);

    controller.setHintToWatchAd();
    expect(controller.state.hintState, PracticeHintState.watchAd);
    controller.unlockHint();
    expect(controller.state.hintState, PracticeHintState.unlocked);

    controller.restartSession();
    expect(controller.state.hintState, PracticeHintState.locked);

    controller.setHintToBuy();
    expect(controller.state.hintState, PracticeHintState.buy);
    controller.unlockHint();
    expect(controller.state.hintState, PracticeHintState.unlocked);
  });
}

