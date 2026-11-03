import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/points_format.dart';

void main() {
  group('formatPoints', () {
    test('trims trailing zeros', () {
      expect(formatPoints(12.5), '12.5 نقطة');
      expect(formatPoints(2), '2 نقطة');
    });

    // Unlike fines, a negative total is real and must be shown as such.
    test('keeps a negative total', () {
      expect(formatPoints(-3), '-3 نقطة');
    });

    test('rounds to two decimals for display', () {
      expect(formatPoints(0.125), '0.13 نقطة');
    });

    test('never shows minus zero', () {
      expect(formatPoints(-0.001), '0 نقطة');
    });
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
