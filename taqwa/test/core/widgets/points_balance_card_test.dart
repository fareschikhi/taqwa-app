import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';
import 'package:taqwa/features/shared/presentation/pages/points_history_page.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

PointEntryModel _entry({
  int id = 1,
  String source = 'PRESENT',
  num amount = 0.5,
  String? reason,
  String? by,
}) => PointEntryModel(
  id: id,
  source: source,
  amount: amount,
  reason: reason,
  createdAt: DateTime.utc(2026, 11, 5, 9),
  date: null,
  createdByName: by,
);

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('shows a negative total in the error color', (tester) async {
    await tester.pumpWidget(
      _host(
        PointsBalanceCard(
          summary: const PointsSummaryModel(total: -3, entries: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(formatPoints(-3)), findsOneWidget);
    expect(_colorOf(tester, formatPoints(-3)), AppColors.error);
  });

  testWidgets('shows a positive total in the primary color', (tester) async {
    await tester.pumpWidget(
      _host(
        PointsBalanceCard(
          summary: const PointsSummaryModel(total: 12.5, entries: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_colorOf(tester, formatPoints(12.5)), AppColors.primary);
  });

  testWidgets('shows at most three recent entries', (tester) async {
    await tester.pumpWidget(
      _host(
        PointsBalanceCard(
          summary: PointsSummaryModel(
            total: 1,
            entries: [
              for (var i = 0; i < 5; i++) _entry(id: i, source: 'PRESENT'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حضور'), findsNWidgets(3));
  });

  // A manual reason is free text up to 300 chars; on a phone-width card it
  // must shorten, not push the amount off the row.
  testWidgets('a long manual reason does not overflow the row', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        PointsBalanceCard(
          summary: PointsSummaryModel(
            total: 2,
            entries: [
              _entry(source: 'MANUAL', amount: 2, reason: 'مشاركة ممتازة ' * 4),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('history shows the empty state', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => const MaterialApp(
          home: PointsHistoryPage(
            summary: PointsSummaryModel(total: 0, entries: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد نقاط مسجلة بعد'), findsOneWidget);
  });

  testWidgets('history shows who made a manual entry', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: PointsHistoryPage(
            summary: PointsSummaryModel(
              total: 2,
              entries: [
                _entry(source: 'MANUAL', amount: 2, reason: 'سلوك', by: 'أحمد'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سلوك'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('بواسطة أحمد'), findsOneWidget);
  });
}
