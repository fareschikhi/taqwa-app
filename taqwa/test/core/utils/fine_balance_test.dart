import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/fine_balance.dart';

void main() {
  group('displayedBalance', () {
    test('passes a positive balance through', () {
      expect(displayedBalance(40), 40);
    });

    test('shows nothing owed as zero', () {
      expect(displayedBalance(0), 0);
    });

    // A charge withdrawn from under an existing reduction can drive the stored
    // sum below zero. Nobody owes a negative amount.
    test('clamps a negative balance to zero', () {
      expect(displayedBalance(-20), 0);
    });
  });

  group('formatFine', () {
    test('appends the currency', () {
      expect(formatFine(50), '50 دج');
    });
  });
}
