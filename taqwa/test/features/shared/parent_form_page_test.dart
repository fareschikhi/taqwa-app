import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/parent/parent_child_model.dart';
import 'package:taqwa/features/data/models/parent/parent_model.dart';
import 'package:taqwa/features/shared/presentation/pages/parent_form_page.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: child),
    );

/// Phone-sized surface. The test font draws every glyph as a full square, so
/// the form's 20sp Arabic section headers overflow their rows here though
/// they fit on a phone. These tests check content, not layout, so RenderFlex
/// overflow reports are dropped; any other error still fails the test.
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
  test('ParentChildModel reads the halaqa id', () {
    final child = ParentChildModel.fromJson({
      'id': 7,
      'user': {'fullName': 'أحمد'},
      'halaqa': {'id': 3, 'name': 'حلقة النور'},
    });

    expect(child.halaqaId, 3);
    expect(child.halaqaName, 'حلقة النور');
  });

  testWidgets('editing a parent lists their students', (tester) async {
    _phoneScreen(tester);
    final parent = ParentModel.fromJson({
      'id': 1,
      'user': {'fullName': 'والد'},
      'students': [
        {
          'id': 7,
          'user': {'fullName': 'أحمد'},
          'halaqa': {'id': 3, 'name': 'حلقة النور'},
        },
        {
          'id': 8,
          'user': {'fullName': 'سارة'},
        },
      ],
    });

    await tester.pumpWidget(_host(ParentFormPage(parent: parent)));
    await tester.pumpAndSettle();

    expect(find.text('الطلاب المرتبطون (2)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('حلقة النور'), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('بدون حلقة'), findsOneWidget);
  });

  testWidgets('creating a parent shows no students section', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host(const ParentFormPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('الطلاب المرتبطون'), findsNothing);
  });
}
