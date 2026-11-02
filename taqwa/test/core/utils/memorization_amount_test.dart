import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/memorization_amount.dart';

TextEditingValue _type(
  TextInputFormatter formatter,
  String before,
  String after,
) => formatter.formatEditUpdate(
  TextEditingValue(text: before),
  TextEditingValue(text: after),
);

void main() {
  group('formatAmount', () {
    test('drops the .0 of a whole amount', () {
      expect(formatAmount(2), '2');
      expect(formatAmount(2.0), '2');
    });

    test('keeps a half', () => expect(formatAmount(1.5), '1.5'));

    test('reads a missing amount as 0', () => expect(formatAmount(null), '0'));
  });

  group('parseAmount', () {
    test('accepts halves where allowed', () {
      expect(parseAmount('1.5', allowHalf: true), 1.5);
      expect(parseAmount('10', allowHalf: true), 10);
      expect(parseAmount('3.', allowHalf: true), 3);
    });

    test('rejects anything finer than a half', () {
      expect(parseAmount('1.3', allowHalf: true), isNull);
      expect(parseAmount('1.25', allowHalf: true), isNull);
    });

    test('rejects a half where only whole amounts are allowed', () {
      expect(parseAmount('1.5', allowHalf: false), isNull);
      expect(parseAmount('4', allowHalf: false), 4);
    });

    test('reads Arabic-Indic digits and a comma separator', () {
      expect(parseAmount('١٠', allowHalf: false), 10);
      expect(parseAmount('٣٫٥', allowHalf: true), 3.5);
      expect(parseAmount('3,5', allowHalf: true), 3.5);
    });

    test('returns null for an empty field', () {
      expect(parseAmount('', allowHalf: true), isNull);
    });
  });

  group('MemorizationAmountInputFormatter', () {
    final halves = MemorizationAmountInputFormatter(allowHalf: true);
    final whole = MemorizationAmountInputFormatter(allowHalf: false);

    test('lets a half page be typed', () {
      expect(_type(halves, '1.', '1.5').text, '1.5');
    });

    test('refuses a digit after the point other than 5', () {
      expect(_type(halves, '1.', '1.3').text, '1.');
    });

    test('refuses the point itself for whole-only units', () {
      expect(_type(whole, '1', '1.').text, '1');
    });

    test('normalizes Arabic-Indic digits as they are typed', () {
      expect(_type(halves, '', '٤').text, '4');
    });

    test('accepts the point after a whole number', () {
      expect(_type(halves, '1', '1.').text, '1.');
    });

    test('reads every keyboard decimal separator as the point', () {
      expect(_type(halves, '1', '1,').text, '1.');
      expect(_type(halves, '1', '1٫').text, '1.');
      expect(_type(halves, '1', '1،').text, '1.');
    });
  });
}
