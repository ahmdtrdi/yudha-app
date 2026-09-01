import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/app/router/app_tab_shell.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

void main() {
  testWidgets('renders an icon-only capsule with a tapered active indicator', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.practiceHistory,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-tab-capsule')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-tab-clay-base')),
      findsOneWidget,
    );
    expect(find.byType(SvgPicture), findsNWidgets(6));
    final ColoredBox practiceNavBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('app-tab-background')),
    );
    expect(practiceNavBackground.color, AppColors.scholarCream);
    expect(find.text('Lobby'), findsNothing);
    expect(find.text('PvP'), findsNothing);
    expect(find.text('Rank'), findsNothing);
    expect(find.text('Practice'), findsNothing);
    expect(find.text('Learning'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('app-tab-indicator-Practice')),
      findsOneWidget,
    );
    final DecoratedBox highlight = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('app-tab-highlight-gradient')),
    );
    final LinearGradient highlightGradient =
        (highlight.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(highlightGradient.begin, Alignment.bottomCenter);
    expect(highlightGradient.end, Alignment.topCenter);
    expect(highlightGradient.colors, hasLength(3));
    expect(highlightGradient.stops, <double>[0, 0.42, 1]);
    expect(highlightGradient.colors.last.a, 0);
    final Rect clayBaseRect = tester.getRect(
      find.byKey(const ValueKey<String>('app-tab-clay-base')),
    );
    final Rect capsuleRect = tester.getRect(
      find.byKey(const ValueKey<String>('app-tab-capsule')),
    );
    final Rect indicatorRect = tester.getRect(
      find.byKey(const ValueKey<String>('app-tab-indicator-Practice')),
    );
    expect(clayBaseRect.top, lessThan(capsuleRect.top));
    expect(indicatorRect.top, closeTo(capsuleRect.top + 1, 1));
    expect(indicatorRect.bottom, closeTo(capsuleRect.bottom - 1, 1));
    final SemanticsNode practiceSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('app-tab-Practice')),
    );
    final SemanticsData practiceData = practiceSemantics.getSemanticsData();
    expect(practiceData.label, 'Practice');
    expect(practiceData.flagsCollection.isButton, isTrue);
    expect(practiceData.flagsCollection.isSelected, ui.Tristate.isTrue);

    final SemanticsNode lobbySemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('app-tab-Lobby')),
    );
    final SemanticsData lobbyData = lobbySemantics.getSemanticsData();
    expect(lobbyData.label, 'Lobby');
    expect(lobbyData.flagsCollection.isButton, isTrue);
    expect(lobbyData.flagsCollection.isSelected, ui.Tristate.isFalse);

    final SemanticsNode learningSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('app-tab-Learning')),
    );
    expect(learningSemantics.getSemanticsData().label, 'Learning');
    expect(
      learningSemantics.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isFalse,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.lobby,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();

    final ColoredBox lobbyNavBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('app-tab-background')),
    );
    expect(lobbyNavBackground.color, AppColors.scholarCream);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppTabShell(
            location: AppRoutes.learning,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('app-tab-indicator-Learning')),
      findsOneWidget,
    );
  });
}
