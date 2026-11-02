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

/// The children picker's candidates: one already this parent's, one held by
/// another parent, one free. Adults are filtered out before this list.
Future<List<ParentChildModel>> _candidates() async => const [
      ParentChildModel(
        id: 7,
        fullName: 'أحمد',
        halaqaId: 3,
        halaqaName: 'حلقة النور',
        parentId: 1,
      ),
      ParentChildModel(id: 11, fullName: 'يوسف', parentId: 5),
      ParentChildModel(id: 12, fullName: 'يونس'),
    ];

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
  test('ParentChildModel reads the halaqa and parent ids', () {
    final child = ParentChildModel.fromJson({
      'id': 7,
      'parentId': 4,
      'user': {'fullName': 'أحمد'},
      'halaqa': {'id': 3, 'name': 'حلقة النور'},
    });

    expect(child.halaqaId, 3);
    expect(child.halaqaName, 'حلقة النور');
    expect(child.parentId, 4);
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

    await tester.pumpWidget(
      _host(ParentFormPage(parent: parent, loadChildCandidates: _candidates)),
    );
    await tester.pumpAndSettle();

    expect(find.text('الطلاب المرتبطون (2)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('حلقة النور'), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('بدون حلقة'), findsOneWidget);
  });

  testWidgets('creating a parent starts with no children picked',
      (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(
      _host(const ParentFormPage(loadChildCandidates: _candidates)),
    );
    await tester.pumpAndSettle();

    expect(find.text('الطلاب المرتبطون (0)'), findsOneWidget);
    expect(find.text('لم يتم اختيار أي طالب بعد.'), findsOneWidget);
  });

  testWidgets('the search filters students and picks one', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(
      _host(const ParentFormPage(loadChildCandidates: _candidates)),
    );
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, 'ابحث عن طالب بالاسم...');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'يو');
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsNothing);
    expect(find.text('يونس'), findsOneWidget);
    expect(
      find.text('مرتبط بولي أمر آخر — سيُنقل إلى هذا الحساب'),
      findsOneWidget,
    );

    await tester.tap(find.text('يونس'));
    await tester.pumpAndSettle();

    expect(find.text('الطلاب المرتبطون (1)'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('إزالة يونس'));
    await tester.tap(find.byTooltip('إزالة يونس'));
    await tester.pumpAndSettle();

    expect(find.text('الطلاب المرتبطون (0)'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(
      _host(
        ParentFormPage(loadChildCandidates: () async => throw Exception()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل قائمة الطلاب.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
