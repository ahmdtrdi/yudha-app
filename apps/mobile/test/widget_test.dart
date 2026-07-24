import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/app/app_root.dart';

void main() {
  testWidgets(
    'shows splash then navigates to login page for unauthenticated users',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: AppRoot()));

      expect(find.text('Menyiapkan arena belajarmu...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang'), findsOneWidget);
      expect(find.text('Masuk ke arena belajar YUDHA.'), findsOneWidget);
    },
  );
}
