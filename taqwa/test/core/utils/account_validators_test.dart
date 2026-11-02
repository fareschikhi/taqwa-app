import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/account_validators.dart';

void main() {
  group('normalizePhone', () {
    // Same cases as the backend's account-fields.spec.ts, so the two can't
    // drift apart unnoticed.
    const cases = {
      '0551234567': '0551234567',
      '05 51 23 45 67': '0551234567',
      '055-123-4567': '0551234567',
      '+213 551 23 45 67': '0551234567',
      '00213661234567': '0661234567',
      '+213 0551 23 45 67': '0551234567',
      '+33 6 12 34 56 78': '+33612345678',
      '0033612345678': '+33612345678',
      '1001': '1001',
    };
    cases.forEach((input, expected) {
      test('$input -> $expected', () {
        expect(AccountValidators.normalizePhone(input), expected);
      });
    });
  });

  group('composePhone', () {
    test('keeps Algerian numbers in local form, with or without the trunk 0', () {
      expect(AccountValidators.composePhone('+213', '551234567'), '0551234567');
      expect(AccountValidators.composePhone('+213', '0551234567'), '0551234567');
    });

    test('stores other countries in international form', () {
      expect(AccountValidators.composePhone('+33', '6 12 34 56 78'), '+33612345678');
    });

    test('a number typed with its own + code wins over the picked one', () {
      expect(AccountValidators.composePhone('+213', '+447700900123'), '+447700900123');
    });

    test('nothing typed means no phone', () {
      expect(AccountValidators.composePhone('+213', '  '), '');
    });
  });

  group('phone', () {
    test('accepts numbers from any country, whatever their length', () {
      for (final v in [
        '0551234567',
        '0451234567',
        '05512345678',
        '+213 551 23 45 67',
        '+33612345678',
        '+12025550123',
      ]) {
        expect(AccountValidators.phone(v), isNull, reason: v);
      }
    });

    test('rejects what is not a phone number', () {
      for (final v in ['1001', 'abc', '+0612345678', '+1234567890123456', '05512']) {
        expect(AccountValidators.phone(v), AccountValidators.phoneError, reason: v);
      }
    });

    test('blank is fine unless required', () {
      expect(AccountValidators.phone(''), isNull);
      expect(AccountValidators.phone('  ', required: true), 'رقم الهاتف مطلوب');
    });
  });

  group('email', () {
    test('blank is fine, since email is optional everywhere', () {
      expect(AccountValidators.email(''), isNull);
    });

    test('accepts a normal address', () {
      expect(AccountValidators.email(' ahmed@example.dz '), isNull);
    });

    test('rejects obvious typos', () {
      for (final v in ['ahmed', 'ahmed@', 'ahmed@example', 'a b@c.com']) {
        expect(AccountValidators.email(v), isNotNull, reason: v);
      }
    });
  });

  group('fullName', () {
    test('requires something other than spaces', () {
      expect(AccountValidators.fullName('   '), 'الاسم مطلوب');
      expect(AccountValidators.fullName('Ahmed Boudiaf'), isNull);
    });

    test('caps the length at the server limit', () {
      expect(AccountValidators.fullName('a' * 101), isNotNull);
    });
  });

  group('password', () {
    test('needs 6 characters on create', () {
      expect(AccountValidators.password(''), isNotNull);
      expect(AccountValidators.password('12345'), isNotNull);
      expect(AccountValidators.password('123456'), isNull);
    });

    test('may be left blank on edit, but a typed one is still checked', () {
      expect(AccountValidators.password('', optional: true), isNull);
      expect(AccountValidators.password('123', optional: true), isNotNull);
    });
  });
}
