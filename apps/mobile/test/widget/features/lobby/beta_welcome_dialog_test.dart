import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/lobby/presentation/beta_welcome_dialog.dart';

void main() {
  testWidgets(
    'bonus confirmation retries acknowledgment without another grant',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => BetaWelcomeDialog(
                    acknowledge: () async {
                      attempts++;
                      if (attempts == 1) throw Exception('offline');
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1.000 koin dan 1.000 energi'),
        findsOneWidget,
      );
      await tester.tap(find.text('Mulai Bermain'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonusmu tetap aman'), findsOneWidget);
      await tester.tap(find.text('Mulai Bermain'));
      await tester.pumpAndSettle();
      expect(find.byType(BetaWelcomeDialog), findsNothing);
      expect(attempts, 2);
    },
  );
}
