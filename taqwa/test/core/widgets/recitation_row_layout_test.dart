import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/widgets/attendance_controls.dart';

/// The recitation row as the student tile builds it: two controls stretched
/// to a common height, inside a list that gives its children an unbounded
/// height, at the width the tile actually has.
///
/// A bare `CrossAxisAlignment.stretch` here asks the children to be infinitely
/// tall and every tile in the halaqa fails to render — which is exactly what
/// shipped once, because the check for it pumped the row inside a `Center` and
/// so handed it a finite height it would not have in the real list.
Widget _recitationRowInList({
  bool intrinsicHeight = true,
  String missedFee = '1000 دج',
}) {
  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: RecitationButton(
          icon: Icons.menu_book_outlined,
          label: 'عرض',
          color: AppColors.primary,
          showBadge: true,
          highlighted: true,
          onTap: () {},
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: RecitationButton(
          icon: Icons.menu_book_outlined,
          strikethrough: true,
          label: 'لم يحفظ',
          subLabel: missedFee,
          color: AppColors.error,
          selected: true,
          onTap: () {},
        ),
      ),
    ],
  );

  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            // 326 is the tile's inner width once the list and tile padding
            // have taken their share.
            SizedBox(
              width: 326,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [intrinsicHeight ? IntrinsicHeight(child: row) : row],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders inside an unbounded list at the tile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_recitationRowInList());

    expect(tester.takeException(), isNull);
    expect(find.text('لم يحفظ'), findsOneWidget);
    expect(find.text('1000 دج'), findsOneWidget);
    expect(find.text('عرض'), findsOneWidget);
  });

  testWidgets('both controls end up exactly the same width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_recitationRowInList());

    final widths = tester
        .widgetList<RecitationButton>(find.byType(RecitationButton))
        .map((button) => tester.getSize(find.byWidget(button)).width)
        .toSet();

    expect(widths, hasLength(1));
  });

  // Half the row is 159w. The label and the largest fee a halaqa might charge
  // both have to sit inside that without ellipsising — a clipped fine amount
  // is worse than a clipped word.
  testWidgets('neither line is clipped by the largest fee', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_recitationRowInList());

    final slot = tester
        .renderObject<RenderBox>(
          find
              .ancestor(
                of: find.text('لم يحفظ'),
                matching: find.byType(RecitationButton),
              )
              .first,
        )
        .size
        .width;

    for (final line in ['لم يحفظ', '1000 دج']) {
      final text = tester.renderObject<RenderBox>(find.text(line));
      expect(text.size.width, lessThan(slot), reason: '"$line" is clipped');
    }
  });

  testWidgets('both controls end up the same height', (tester) async {
    await tester.pumpWidget(_recitationRowInList());

    final heights = tester
        .widgetList<RecitationButton>(find.byType(RecitationButton))
        .map((button) => tester.getSize(find.byWidget(button)).height)
        .toSet();

    expect(heights, hasLength(1));
  });

  // Guards the diagnosis itself: if a future Flutter makes a bare stretch
  // legal here, this fails and the IntrinsicHeight can come back out.
  testWidgets('a bare stretch would still break the list', (tester) async {
    await tester.pumpWidget(_recitationRowInList(intrinsicHeight: false));

    expect(tester.takeException(), isNotNull);
  });
}
