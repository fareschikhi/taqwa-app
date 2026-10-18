import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/parent/halaqa_manager_contact_model.dart';

HalaqaManagerContactModel _withPhone(String phone) =>
    HalaqaManagerContactModel(id: 1, fullName: 'أحمد', phone: phone);

void main() {
  group('telegramUri', () {
    test('turns a stored local mobile into the international number', () {
      expect(
        _withPhone('0551234567').telegramUri.toString(),
        'https://t.me/+213551234567',
      );
    });

    test('keeps a number that is already international', () {
      expect(
        _withPhone('+213 771 23 45 67').telegramUri.toString(),
        'https://t.me/+213771234567',
      );
      expect(
        _withPhone('00213771234567').telegramUri.toString(),
        'https://t.me/+213771234567',
      );
    });

    test('is null when there is nothing to dial', () {
      expect(_withPhone('').telegramUri, isNull);
      expect(_withPhone('123').telegramUri, isNull);
    });
  });

  test('listFromProfile reads the halaqa managers and skips the unreachable', () {
    final managers = HalaqaManagerContactModel.listFromProfile({
      'halaqa': {
        'name': 'حلقة الفجر',
        'managers': [
          {
            'manager': {
              'id': 3,
              'user': {'fullName': 'يوسف', 'phone': '0661234567'},
            },
          },
          {
            'manager': {
              'id': 4,
              'user': {'fullName': 'بلا هاتف', 'phone': null},
            },
          },
        ],
      },
    });

    expect(managers.map((m) => m.fullName), ['يوسف']);
    expect(managers.single.id, 3);
  });

  test('listFromProfile is empty for a child with no halaqa', () {
    expect(HalaqaManagerContactModel.listFromProfile({'halaqa': null}), isEmpty);
  });
}
