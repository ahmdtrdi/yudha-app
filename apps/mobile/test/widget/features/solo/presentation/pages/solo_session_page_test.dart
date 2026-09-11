import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_providers.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';
import 'package:yudha_mobile/features/solo/presentation/pages/solo_session_page.dart';

void main() {
  testWidgets('finishing Solo refreshes daily missions without leaving the result', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = SoloSessionController(_ArenaSoloRepository(completed: true));
    final progress = _MissionProgressController();
    await controller.start(
      count: SoloQuestionCount.twenty,
      characterId: 'character-basic-squire',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          soloSessionControllerProvider.overrideWith((Ref ref) => controller),
          playerProgressProvider.overrideWith((Ref ref) => progress),
        ],
        child: const MaterialApp(home: SoloSessionPage()),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('question-card-sq-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('solo-option-2')));
    await tester.pump();
    expect(controller.state.session!.isActive, isFalse);
    expect(progress.refreshCalls, 1);
    expect(progress.state.dailyMissions.single['completed'], isTrue);
    await tester.pump();
    expect(progress.refreshCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an expired card automatically shows wrong-answer feedback', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ArenaSoloRepository(expired: true);
    final controller = SoloSessionController(repository);
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
    await tester.tap(find.byKey(const ValueKey<String>('question-card-sq-1')));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(repository.answerCalls, 1);
    expect(controller.state.feedback?.timedOut, isTrue);
    expect(controller.state.selectedOption, isIn([0, 1, 3]));
    await tester.pump(const Duration(seconds: 2));
    expect(repository.answerCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

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

    await tester.tap(find.byKey(const ValueKey<String>('solo-back-to-cards')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('solo-question-sheet')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('question-card-sq-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('solo-show-hint')));
    await tester.pump();
    expect(find.text('Petunjuk server.'), findsOneWidget);

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

class _MissionProgressController extends PlayerProgressController {
  int refreshCalls = 0;

  @override
  Future<void> hydrateFromRepository() async {
    refreshCalls++;
    state = state.copyWith(dailyMissions: const [
      {'key': 'daily_practice', 'completed': true, 'progress': 1},
    ]);
  }
}

class _ArenaSoloRepository extends SoloRepository {
  _ArenaSoloRepository({this.expired = false, this.completed = false})
    : super(accessToken: 'token');

  final bool expired;
  final bool completed;
  int answerCalls = 0;

  @override
  Future<SoloSession> create({
    required SoloQuestionCount questionCount,
    required String characterId,
    SoloMechanicMode mechanicMode = SoloMechanicMode.standard,
    SoloQuestionSelection questionSelection =
        const SoloBalancedQuestionSelection(),
    String? recommendationId,
  }) async => _session(mechanicMode: mechanicMode);

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
      deadlineAt: now.add(Duration(seconds: expired ? -1 : 30)),
    );
  }

  @override
  Future<SoloAnswerResponse> answer(
    String sessionId,
    String questionId,
    int? selectedOptionIndex, {
    int? clientActiveResponseTimeMs,
    int? backgroundDurationMs,
  }) async {
    answerCalls += 1;
    return SoloAnswerResponse(
      session: _session(answeredCount: 1, correctCount: 1, towerHp: 95, completed: completed),
      feedback: SoloAnswerFeedback(
        sessionQuestionId: 'sq-1',
        isCorrect: selectedOptionIndex != null,
        timedOut: selectedOptionIndex == null,
        correctOptionIndex: 2,
        explanation: 'Pembahasan.',
      ),
    );
  }

  @override
  Future<SoloHint> requestHint(String sessionId, String questionId) async {
    return SoloHint(hint: 'Petunjuk server.', requestedAt: DateTime.now());
  }
}

SoloSession _session({
  int answeredCount = 0,
  int correctCount = 0,
  int towerHp = 100,
  SoloMechanicMode mechanicMode = SoloMechanicMode.standard,
  bool completed = false,
}) {
  return SoloSession(
    id: 'solo-1',
    target: 'cpns',
    questionCount: 20,
    characterId: 'character-basic-squire',
    status: completed ? 'completed' : 'active',
    answeredCount: answeredCount,
    correctCount: correctCount,
    towerHp: towerHp,
    rewardCoins: 0,
    mechanicMode: mechanicMode,
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
