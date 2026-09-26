import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/parent/parent_model.dart';
import 'package:taqwa/features/shared/presentation/pages/parent_details_page.dart';

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

final _parent = ParentModel.fromJson({
  'id': 1,
  'address': 'الجزائر العاصمة',
  'user': {
    'id': 10,
    'fullName': 'والد',
    'phone': '0555123456',
    'isActive': false,
  },
  'students': [
    {
      'id': 7,
      'user': {'fullName': 'أحمد'},
      'halaqa': {'id': 3, 'name': 'حلقة النور'},
    },
  ],
});

void main() {
  testWidgets('shows the contact details and linked students', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host(ParentDetailsPage(parent: _parent)));
    await tester.pumpAndSettle();

    expect(find.text('والد'), findsOneWidget);
    expect(find.text('غير نشط'), findsOneWidget);
    expect(find.text('0555123456'), findsOneWidget);
    expect(find.text('الجزائر العاصمة'), findsOneWidget);
    // No email on the account: the row says so instead of disappearing.
    expect(find.text('غير مسجل'), findsOneWidget);
    expect(find.text('الأبناء (1)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('حلقة النور'), findsOneWidget);
  });

  testWidgets('the edit button only shows when allowed', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host(ParentDetailsPage(parent: _parent)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.pumpWidget(
      _host(ParentDetailsPage(parent: _parent, canEdit: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('a parent with no students says so', (tester) async {
    _phoneScreen(tester);
    final parent = ParentModel.fromJson({
      'id': 2,
      'user': {'fullName': 'أم'},
    });
    await tester.pumpWidget(_host(ParentDetailsPage(parent: parent)));
    await tester.pumpAndSettle();

    expect(find.text('الأبناء (0)'), findsOneWidget);
    expect(find.text('لا يوجد طلاب مرتبطون بولي الأمر هذا.'), findsOneWidget);
  });
}
