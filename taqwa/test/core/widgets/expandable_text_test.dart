import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/expandable_text.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _pump(WidgetTester tester, String text) async {
  await tester.pumpWidget(_host(ExpandableText(text, maxLines: 2)));
  // The overflow is read after the first frame; this frame shows its result.
  await tester.pump();
}

Text _paragraph(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text).first);

void main() {
  const short = 'أحسن اليوم في المراجعة';
  final long = List.filled(40, 'أحسن الطالب اليوم في المراجعة').join(' ');

  testWidgets('a message that fits gets no read-more button', (tester) async {
    await _pump(tester, short);

    expect(find.text(short), findsOneWidget);
    expect(find.text('اقرأ المزيد'), findsNothing);
  });

  testWidgets('a long message is folded with a read-more button', (
    tester,
  ) async {
    await _pump(tester, long);

    expect(_paragraph(tester).maxLines, 2);
    expect(find.text('اقرأ المزيد'), findsOneWidget);
  });

  testWidgets('read more opens the whole message and show less folds it', (
    tester,
  ) async {
    await _pump(tester, long);

    await tester.tap(find.text('اقرأ المزيد'));
    await tester.pump();
    expect(_paragraph(tester).maxLines, isNull);
    expect(find.text('عرض أقل'), findsOneWidget);

    await tester.tap(find.text('عرض أقل'));
    await tester.pump();
    expect(_paragraph(tester).maxLines, 2);
    expect(find.text('اقرأ المزيد'), findsOneWidget);
  });

  testWidgets('works inside IntrinsicHeight, as the note timeline uses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(IntrinsicHeight(child: ExpandableText(long, maxLines: 2))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('اقرأ المزيد'), findsOneWidget);
  });
}
