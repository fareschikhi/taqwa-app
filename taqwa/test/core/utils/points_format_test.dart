import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/utils/points_format.dart';

void main() {
  group('formatPoints', () {
    // The number is led by an LRM mark (U+200E) so it keeps its own
    // left-to-right order inside the Arabic sentence; strip it to read it.
    String plain(String s) => s.replaceAll('‎', '');

    test('trims trailing zeros', () {
      expect(plain(formatPoints(12.5)), '12.5 نقطة');
      expect(plain(formatPoints(2)), '2 نقطة');
    });

    // Unlike fines, a negative total is real and must be shown as such.
    test('keeps a negative total', () {
      expect(plain(formatPoints(-3)), '-3 نقطة');
    });

    test('rounds to two decimals for display', () {
      expect(plain(formatPoints(0.125)), '0.13 نقطة');
    });

    test('never shows minus zero', () {
      expect(plain(formatPoints(-0.001)), '0 نقطة');
    });

    // Someone looking at points they can't change sees only the whole part.
    test('drops the decimals when whole is asked for', () {
      expect(plain(formatPoints(12.2, whole: true)), '12 نقطة');
      expect(plain(formatPoints(1.5, whole: true)), '1 نقطة');
      expect(plain(formatPoints(-1.5, whole: true)), '-1 نقطة');
      expect(plain(formatPoints(-0.5, whole: true)), '0 نقطة');
    });

    // AppText lays an Arabic string out right-to-left. Without the LRM, the
    // bidi algorithm puts the minus on the far side of the digit: "3-".
    for (final text in [formatPoints(-3), 'المجموع: ${formatPoints(-3)}']) {
      test('draws the minus left of the digit in "$text"', () {
        final painter = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
          textDirection: AppText.directionOf(text),
        )..layout();
        double leftOf(String char) {
          final i = text.indexOf(char);
          return painter
              .getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1),
              )
              .single
              .left;
        }

        expect(leftOf('-'), lessThan(leftOf('3')));
      });
    }
  });

  group('formatSignedPoints', () {
    test('signs every non-zero amount', () {
      expect(formatSignedPoints(0.5), '+0.5');
      expect(formatSignedPoints(-1), '-1');
    });
  });

  group('parsePoints', () {
    test('reads the exact strings the API sends', () {
      expect(parsePoints('-0.5'), -0.5);
      expect(parsePoints(2), 2);
    });

    test('treats missing or malformed values as zero', () {
      expect(parsePoints(null), 0);
      expect(parsePoints('abc'), 0);
    });
  });
}
