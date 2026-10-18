import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/pages/manager_details_page.dart';
import 'package:taqwa/features/data/models/manager_model.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: child),
);

/// Phone-sized surface. The test font draws every glyph as a full square, so
/// Arabic headings can overflow rows that fit on a phone. These tests check
/// content, not layout, so RenderFlex overflow reports are dropped; any other
/// error still fails the test.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  testWidgets('shows contact, halaqas and permissions', (tester) async {
    _phoneScreen(tester);
    // Shaped like GET /managers: halaqas arrive as ManagerHalaqa join rows.
    final manager = ManagerModel.fromJson({
      'id': 4,
      'canManageAccounts': true,
      'canDeleteAccounts': false,
      'user': {'fullName': 'مدير', 'email': 'm@taqwa.dz', 'isActive': true},
      'halaqas': [
        {
          'halaqa': {'id': 3, 'name': 'حلقة النور', 'level': 'مبتدئ'},
        },
      ],
      '_count': {'justifications': 5},
    });

    await tester.pumpWidget(_host(ManagerDetailsPage(manager: manager)));
    await tester.pumpAndSettle();

    expect(find.text('مدير'), findsOneWidget);
    expect(find.text('نشط'), findsOneWidget);
    expect(find.text('m@taqwa.dz'), findsOneWidget);
    // No phone on the account.
    expect(find.text('غير مسجل'), findsOneWidget);
    expect(find.text('الحلقات المعينة (1)'), findsOneWidget);
    expect(find.text('حلقة النور'), findsOneWidget);
    expect(find.text('مبتدئ'), findsOneWidget);
    expect(find.text('مسموح'), findsOneWidget);
    expect(find.text('غير مسموح'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    // No number, so nothing to open Telegram with.
    expect(find.text('تواصل عبر تيليجرام'), findsNothing);
  });

  testWidgets('offers Telegram when the manager has a phone', (tester) async {
    _phoneScreen(tester);
    final manager = ManagerModel.fromJson({
      'id': 6,
      'user': {'fullName': 'مدير', 'phone': '0551234567'},
      'halaqas': [],
    });

    await tester.pumpWidget(_host(ManagerDetailsPage(manager: manager)));
    await tester.pumpAndSettle();

    expect(find.text('تواصل عبر تيليجرام'), findsOneWidget);
  });

  testWidgets('a manager with no halaqas says so', (tester) async {
    _phoneScreen(tester);
    final manager = ManagerModel.fromJson({
      'id': 5,
      'user': {'fullName': 'مدير'},
      'halaqas': [],
    });

    await tester.pumpWidget(_host(ManagerDetailsPage(manager: manager)));
    await tester.pumpAndSettle();

    expect(find.text('الحلقات المعينة (0)'), findsOneWidget);
    expect(find.text('لم تُعيَّن أي حلقة لهذا المدير.'), findsOneWidget);
  });
}
