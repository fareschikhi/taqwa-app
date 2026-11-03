import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';
import 'package:taqwa/features/shared/presentation/pages/points_history_page.dart';

import '../../helpers/stub_api.dart';

PointEntryModel _manual({required int id, required int by}) => PointEntryModel(
  id: id,
  source: 'MANUAL',
  amount: 2,
  reason: 'سلوك $id',
  createdAt: DateTime.utc(2026, 11, 5, 9),
  date: null,
  createdByName: 'أحمد',
  createdById: by,
);

final _undo = find.byTooltip('حذف التعديل');

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  reloadFailureTests();
  final twoEntries = PointsSummaryModel(
    total: 4,
    entries: [_manual(id: 1, by: 5), _manual(id: 2, by: 6)],
  );

  testWidgets('offers undo on the viewer\'s own manual entry only', (
    tester,
  ) async {
    await _pump(
      tester,
      PointsHistoryPage(
        summary: twoEntries,
        reload: () async => twoEntries,
        viewerId: 5,
      ),
    );

    expect(_undo, findsOneWidget);
  });

  testWidgets('the admin may undo every manual entry', (tester) async {
    await _pump(
      tester,
      PointsHistoryPage(
        summary: twoEntries,
        reload: () async => twoEntries,
        viewerId: 1,
        viewerIsAdmin: true,
      ),
    );

    expect(_undo, findsNWidgets(2));
  });

  // Parents and students open the history read-only: no reload, no undo.
  testWidgets('a read-only history offers no undo', (tester) async {
    await _pump(
      tester,
      PointsHistoryPage(summary: twoEntries, viewerId: 5, viewerIsAdmin: true),
    );

    expect(_undo, findsNothing);
  });

  testWidgets('undo confirms, deletes, then shows the reloaded history', (
    tester,
  ) async {
    final api = StubApi.install((_) => (200, {}));
    final after = PointsSummaryModel(
      total: 2,
      entries: [_manual(id: 2, by: 6)],
    );
    await _pump(
      tester,
      PointsHistoryPage(
        summary: twoEntries,
        reload: () async => after,
        viewerId: 5,
      ),
    );

    await tester.tap(_undo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(api.sent('DELETE', '/points/1'), hasLength(1));
    expect(find.text('سلوك 1'), findsNothing);
    expect(find.text('تم حذف التعديل'), findsOneWidget);
  });
}

void reloadFailureTests() {
  // The delete worked; only the refresh after it failed. Saying "failed"
  // would invite a second tap and a confusing 404.
  testWidgets('a failed reload after a delete still reports the delete', (
    tester,
  ) async {
    StubApi.install((_) => (200, {}));
    await _pump(
      tester,
      PointsHistoryPage(
        summary: PointsSummaryModel(
          total: 4,
          entries: [_manual(id: 1, by: 5), _manual(id: 2, by: 6)],
        ),
        reload: () async => throw Exception('offline'),
        viewerId: 5,
      ),
    );

    await tester.tap(_undo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(find.text('تم حذف التعديل'), findsOneWidget);
    expect(find.text('سلوك 1'), findsNothing);
    expect(_undo, findsNothing);
  });
}
