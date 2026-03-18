import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/app_root.dart';

void main() {
  testWidgets('shows lobby as initial screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AppRoot()));
    await tester.pumpAndSettle();

    expect(find.text('YUDHA Lobby'), findsOneWidget);
    expect(find.text('Today\'s Quest'), findsOneWidget);
    expect(find.text('Start Battle'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
  });
}
