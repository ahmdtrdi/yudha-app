import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_page.dart';

void main() {
  testWidgets('renders profile sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfilePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profil Personal'), findsOneWidget);
    expect(find.text('Analisis Performa'), findsOneWidget);
    expect(find.text('Pengaturan Profil'), findsOneWidget);
    expect(find.text('Target aktif: -'), findsOneWidget);
    expect(find.text('Bahasa aktif: Bahasa Indonesia'), findsOneWidget);
  });

  testWidgets('can switch active language label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfilePage()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Bahasa aktif: English'), findsOneWidget);
  });

  testWidgets('can switch active target label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfilePage()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('BUMN'));
    await tester.pumpAndSettle();

    expect(find.text('Target aktif: BUMN'), findsOneWidget);
  });
}
