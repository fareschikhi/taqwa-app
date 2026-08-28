// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/auth/presentation/pages/login_page.dart';
import 'package:taqwa/main.dart';

void main() {
  testWidgets('Taqwa app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TaqwaApp());
    expect(find.byType(TaqwaApp), findsOneWidget);
  });

  testWidgets('the app lays out right-to-left for Arabic', (tester) async {
    await tester.pumpWidget(const TaqwaApp());
    await tester.pump();

    final context = tester.element(find.byType(LoginPage));
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
