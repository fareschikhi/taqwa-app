import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/search_bar_widget.dart';

/// The app runs in a forced left-to-right tree, which is fine for alignment —
/// every screen right-aligns explicitly — but not for text. A label mixing an
/// Arabic word with digits and parentheses resolves those neutral characters
/// against the paragraph's base direction, so under LTR the count lands on the
/// wrong side of the word. The label has to declare RTL for itself.
Future<void> pumpChips(WidgetTester tester, List<String> filters) {
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: FilterChipGroup(filters: filters)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a count label resolves right-to-left inside an LTR tree', (
    tester,
  ) async {
    await pumpChips(tester, ['الكل (9)', 'نشط (8)']);
    await tester.pump();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('الكل (9)'),
    );

    expect(paragraph.textDirection, TextDirection.rtl);
  });

  testWidgets('every chip label resolves right-to-left, not just the first', (
    tester,
  ) async {
    await pumpChips(tester, ['الكل (9)', 'غير نشط (1)']);
    await tester.pump();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('غير نشط (1)'),
    );

    expect(paragraph.textDirection, TextDirection.rtl);
  });
}
