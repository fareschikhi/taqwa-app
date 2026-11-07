import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/hadith_program_card.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('shows only hadiths when nothing was counted in pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const HadithProgramCard(books: ['عُمدة الأحكام'], hadithsDone: 4)),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 حديث محفوظ'), findsOneWidget);
  });

  // Hadiths and pages are different units, so they are listed side by side,
  // never added up.
  testWidgets('lists hadith pages next to single hadiths', (tester) async {
    await tester.pumpWidget(
      _host(
        const HadithProgramCard(
          books: ['عُمدة الأحكام'],
          hadithsDone: 4,
          hadithPagesDone: 2.5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 حديث · 2.5 صفحة محفوظ'), findsOneWidget);
  });

  testWidgets('shows only pages when no single hadith was counted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const HadithProgramCard(
          books: ['عُمدة الأحكام'],
          hadithsDone: 0,
          hadithPagesDone: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 صفحة محفوظ'), findsOneWidget);
  });
}
