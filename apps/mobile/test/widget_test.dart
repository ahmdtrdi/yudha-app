import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/app_root.dart';

void main() {
  testWidgets('shows splash then navigates to first-time profile setup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AppRoot()));

    expect(find.text('Menyiapkan arena belajarmu...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('Siapa nama kamu?'), findsOneWidget);
    expect(find.text('Target belajar'), findsOneWidget);
  });
}
