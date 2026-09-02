import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_providers.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_session_page.dart';

void main() {
  testWidgets('renders the PvP-style tower-only Solo arena', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _ArenaSoloRepository repository = _ArenaSoloRepository();
    final SoloSessionController controller = SoloSessionController(repository);
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          soloSessionControllerProvider.overrideWith((Ref ref) => controller),
        ],
        child: const MaterialApp(home: SoloSessionPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey<String>('solo-battle-hud')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-opponent-tower')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-player-character')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-battle-deck-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('combo-meter')), findsNothing);
    expect(find.byKey(const ValueKey<String>('round-clock')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('solo-player-tower')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-opponent-character')),
      findsNothing,
    );
    for (int order = 1; order <= 3; order++) {
      expect(
        find.byKey(ValueKey<String>('solo-card-sq-$order')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey<String>('solo-stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey<String>('solo-music-volume-slider')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('solo-pause-resume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey<String>('question-card-sq-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey<String>('solo-question-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('solo-question-countdown')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('solo-option-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.state.reaction, SoloReaction.idle);
    expect(
      find.byKey(const ValueKey<String>('solo-attack-projectile')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('solo-session-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.state.reaction, SoloReaction.attack);
    expect(
      find.byKey(const ValueKey<String>('solo-attack-projectile')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.state.reaction, SoloReaction.idle);
  });
}

class _ArenaSoloRepository extends SoloRepository {
  _ArenaSoloRepository() : super(accessToken: 'token');

  @override
  Future<SoloSession> create({
    required SoloQuestionCount questionCount,
    required String characterId,
  }) async => _session();

  @override
  Future<SoloQuestion> open(String sessionId, String questionId) async {
    final DateTime now = DateTime.now();
    return SoloQuestion(
      sessionQuestionId: questionId,
      questionOrder: 1,
      category: 'twk',
      prompt: 'Pertanyaan arena?',
      options: const <String>['A', 'B', 'C', 'D'],
      timeLimitSeconds: 30,
      hint: 'Petunjuk.',
      openedAt: now,
      deadlineAt: now.add(const Duration(seconds: 30)),
    );
  }

  @override
  Future<SoloAnswerResponse> answer(
    String sessionId,
    String questionId,
    int? optionIndex,
    bool usedHint,
  ) async {
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
}

SoloSession _session({
  int answeredCount = 0,
  int correctCount = 0,
  int towerHp = 100,
}) {
  return SoloSession(
    id: 'solo-1',
    target: 'cpns',
    questionCount: 20,
    characterId: 'character-basic-squire',
    status: 'active',
    answeredCount: answeredCount,
    correctCount: correctCount,
    towerHp: towerHp,
    rewardCoins: 0,
    hand: <SoloHandCard>[
      for (int order = answeredCount + 1; order <= answeredCount + 3; order++)
        SoloHandCard(
          sessionQuestionId: 'sq-$order',
          questionOrder: order,
          category: order.isOdd ? 'twk' : 'tiu',
          subcategory: order.isOdd ? 'twk' : 'logika',
        ),
    ],
  );
}
