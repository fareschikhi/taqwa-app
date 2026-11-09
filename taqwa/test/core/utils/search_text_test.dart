import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/search_text.dart';

void main() {
  group('matchesSearch', () {
    test('finds a name written with a shadda and a space', () {
      expect(matchesSearch('عبدالرحمان', ['عبد الرّحمان']), isTrue);
    });

    test('ignores harakat and tatweel on either side', () {
      expect(matchesSearch('محمّد', ['محمد']), isTrue);
      expect(matchesSearch('محمد', ['مُحَمَّـــد']), isTrue);
    });

    test('treats alef forms, ya/alef maqsura and ta marbuta as one', () {
      expect(matchesSearch('احمد', ['أحمد']), isTrue);
      expect(matchesSearch('اسلام', ['إسلام']), isTrue);
      expect(matchesSearch('مصطفي', ['مصطفى']), isTrue);
      expect(matchesSearch('فاطمه', ['فاطمة']), isTrue);
    });

    test('still rejects a different name', () {
      expect(matchesSearch('عبدالله', ['عبد الرّحمان']), isFalse);
    });

    test('matches any of the fields, case-insensitively', () {
      expect(matchesSearch('0555', ['علي', '0555 12 34 56']), isTrue);
      expect(matchesSearch('ali', ['ALI Ben']), isTrue);
    });

    test('an empty or blank query matches everything', () {
      expect(matchesSearch('', ['علي']), isTrue);
      expect(matchesSearch('   ', ['علي']), isTrue);
    });

    test('skips null fields', () {
      expect(matchesSearch('علي', [null, 'علي']), isTrue);
      expect(matchesSearch('علي', [null]), isFalse);
    });
  });
}
