import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// The app runs in a forced left-to-right tree. That is fine for layout —
/// every screen right-aligns explicitly — but a paragraph's base direction
/// decides where its leading and trailing neutral characters land, so an
/// Arabic sentence ending in '.' or '*' renders its punctuation on the wrong
/// side. Numbers, dates and Latin names have the opposite problem under RTL,
/// so the direction follows the content rather than being forced either way.
Future<void> pumpText(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

RenderParagraph paragraphOf(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  testWidgets('an Arabic sentence resolves right-to-left', (tester) async {
    const text = 'لا يمكن التراجع عن هذا الإجراء.';
    await pumpText(tester, const AppText(text));

    expect(paragraphOf(tester, text).textDirection, TextDirection.rtl);
  });

  testWidgets('an Arabic label with a trailing marker resolves right-to-left', (
    tester,
  ) async {
    const text = 'اسم الحلقة *';
    await pumpText(tester, const AppText(text));

    expect(paragraphOf(tester, text).textDirection, TextDirection.rtl);
  });

  testWidgets('a percentage stays left-to-right', (tester) async {
    await pumpText(tester, const AppText('75%'));

    expect(paragraphOf(tester, '75%').textDirection, TextDirection.ltr);
  });

  testWidgets('a date stays left-to-right', (tester) async {
    await pumpText(tester, const AppText('01/05/2012'));

    expect(paragraphOf(tester, '01/05/2012').textDirection, TextDirection.ltr);
  });

  testWidgets('a Latin name stays left-to-right', (tester) async {
    await pumpText(tester, const AppText('Djamel Kaddour'));

    expect(
      paragraphOf(tester, 'Djamel Kaddour').textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('mixed Arabic and Latin follows the Arabic', (tester) async {
    const text = 'PNG أو JPG (الحد الأقصى 2MB)';
    await pumpText(tester, const AppText(text));

    expect(paragraphOf(tester, text).textDirection, TextDirection.rtl);
  });

  testWidgets('an explicit direction always wins', (tester) async {
    const text = 'لا يمكن التراجع عن هذا الإجراء.';
    await pumpText(
      tester,
      const AppText(text, textDirection: TextDirection.ltr),
    );

    expect(paragraphOf(tester, text).textDirection, TextDirection.ltr);
  });

  testWidgets('style, alignment and maxLines are forwarded', (tester) async {
    const style = TextStyle(fontSize: 21);
    await pumpText(
      tester,
      const AppText(
        'مرحباً',
        style: style,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final widget = tester.widget<Text>(find.text('مرحباً'));
    expect(widget.style, style);
    expect(widget.textAlign, TextAlign.center);
    expect(widget.maxLines, 2);
    expect(widget.overflow, TextOverflow.ellipsis);
  });
}
