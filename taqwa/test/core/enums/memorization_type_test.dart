import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/enums/memorization_type.dart';

void main() {
  group('MemorizationType units', () {
    test('حفظ is counted in pages', () {
      expect(MemorizationType.hifz.unitLabel, 'صفحة');
      expect(MemorizationType.hifz.amountLabel, 'عدد الصفحات');
      expect(MemorizationType.hifz.maxAmount, 604);
    });

    test('both revisions are counted in hizbs', () {
      for (final type in [
        MemorizationType.minorReview,
        MemorizationType.majorReview,
      ]) {
        expect(type.unitLabel, 'حزب');
        expect(type.amountLabel, 'عدد الأحزاب');
        expect(type.maxAmount, 60);
      }
    });
  });

  group('MemorizationTypeX.fromApi', () {
    test('parses every value apiValue can produce', () {
      for (final type in MemorizationType.values) {
        expect(MemorizationTypeX.fromApi(type.apiValue), type);
      }
    });

    test('returns null for null or unrecognised values', () {
      // Read screens take this straight off untyped JSON, so a missing or
      // unexpected type must not throw at them.
      expect(MemorizationTypeX.fromApi(null), isNull);
      expect(MemorizationTypeX.fromApi(''), isNull);
      expect(MemorizationTypeX.fromApi('REVISION'), isNull);
    });
  });
}
