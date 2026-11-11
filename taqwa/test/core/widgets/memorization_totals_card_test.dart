import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/progress_totals.dart';
import 'package:taqwa/core/widgets/memorization_totals_card.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('shows a tile per unit, pages on the right of ayahs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MemorizationTotalsCard(
          title: 'القرآن الكريم',
          icon: Icons.menu_book_outlined,
          totals: quranTotals(pages: 12, ayahs: 40),
          subtitle: '3 سورة تم تناولها',
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('3 سورة تم تناولها'), findsOneWidget);
    // Read right to left: pages first, so further right on screen.
    expect(
      tester.getCenter(find.text('صفحة')).dx,
      greaterThan(tester.getCenter(find.text('آية')).dx),
    );
  });

  testWidgets('a student counted only in hadiths shows one tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MemorizationTotalsCard(
          title: 'الحديث الشريف',
          icon: Icons.auto_stories_outlined,
          totals: hadithTotals(hadiths: 4),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('حديث'), findsOneWidget);
    expect(find.text('صفحة'), findsNothing);
  });
}
