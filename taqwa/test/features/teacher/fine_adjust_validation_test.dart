import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/fine_balance.dart';

void main() {
  group('fineAdjustError', () {
    test('accepts a charge of any amount', () {
      expect(
        fineAdjustError(amount: 500, kind: 'CHARGE', balance: 0),
        isNull,
      );
    });

    test('accepts a reduction within the balance', () {
      expect(
        fineAdjustError(amount: 20, kind: 'REDUCTION', balance: 70),
        isNull,
      );
    });

    test('accepts a reduction that exactly clears the balance', () {
      expect(
        fineAdjustError(amount: 70, kind: 'REDUCTION', balance: 70),
        isNull,
      );
    });

    // The floor is the whole point of the feature: a teacher must not be able
    // to push a student into credit.
    test('rejects a reduction larger than the balance', () {
      expect(
        fineAdjustError(amount: 100, kind: 'REDUCTION', balance: 70),
        'قيمة الخصم أكبر من الرصيد المستحق',
      );
    });

    test('rejects a zero amount', () {
      expect(
        fineAdjustError(amount: 0, kind: 'CHARGE', balance: 0),
        'أدخل مبلغاً أكبر من صفر',
      );
    });
  });
}
