import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/fine_balance_card.dart';
import 'package:taqwa/features/data/models/fine/fine_entry_model.dart';
import 'package:taqwa/features/data/models/fine/fine_summary_model.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

FineEntryModel _entry({
  int id = 1,
  String kind = 'CHARGE',
  int amount = 10,
  String? reason,
  String source = 'ABSENCE',
}) {
  return FineEntryModel(
    id: id,
    kind: kind,
    amount: amount,
    reason: reason,
    source: source,
    createdAt: DateTime.utc(2026, 8, 7),
  );
}

void main() {
  testWidgets('shows the balance with its currency', (tester) async {
    await tester.pumpWidget(
      _host(
        FineBalanceCard(
          summary: const FineSummaryModel(balance: 70, entries: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('70 دج'), findsOneWidget);
  });

  testWidgets('shows a cleared balance rather than hiding the card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FineBalanceCard(
          summary: const FineSummaryModel(balance: 0, entries: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 دج'), findsOneWidget);
  });

  testWidgets('labels an absence charge from its source', (tester) async {
    await tester.pumpWidget(
      _host(
        FineBalanceCard(
          summary: FineSummaryModel(
            balance: 10,
            entries: [_entry(source: 'ABSENCE', reason: null)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('غياب'), findsOneWidget);
  });
}
