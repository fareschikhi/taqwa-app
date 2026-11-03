import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/points_adjust.dart';

void main() {
  group('parsePointsAmount', () {
    test('reads a dot or a comma as the decimal separator', () {
      expect(parsePointsAmount('1.5'), 1.5);
      // Arabic and French keyboards put a comma there.
      expect(parsePointsAmount('0,5'), 0.5);
    });

    test('reads Arabic-Indic digits', () {
      expect(parsePointsAmount('٢'), 2);
      expect(parsePointsAmount('١٫٥'), 1.5);
    });

    test('returns null for text that is not a number', () {
      expect(parsePointsAmount(''), isNull);
      expect(parsePointsAmount('abc'), isNull);
    });
  });

  group('pointsAdjustError', () {
    test('accepts up to two decimals within the cap', () {
      expect(pointsAdjustError('2.25', ''), isNull);
      expect(pointsAdjustError('1000', 'سلوك'), isNull);
      expect(pointsAdjustError('0.01', ''), isNull);
    });

    test('wants a number above zero', () {
      for (final text in ['', 'abc', '0', '-2']) {
        expect(pointsAdjustError(text, ''), 'أدخل عدداً أكبر من صفر');
      }
    });

    test('caps the amount at 1000', () {
      expect(pointsAdjustError('1000.5', ''), 'أقصى قيمة هي 1000');
    });

    test('allows two decimals at most', () {
      expect(pointsAdjustError('2.255', ''), 'رقمان بعد الفاصلة على الأكثر');
    });

    test('limits the reason to 300 characters', () {
      expect(
        pointsAdjustError('1', 'a' * 301),
        'السبب طويل جداً (300 حرف على الأكثر)',
      );
      expect(pointsAdjustError('1', 'a' * 300), isNull);
    });
  });
}
