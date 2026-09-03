import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/enums/memorization_subject.dart';

void main() {
  group('MemorizationSubjectX', () {
    test('labels each subject in Arabic', () {
      expect(MemorizationSubject.quran.label, 'القرآن');
      expect(MemorizationSubject.hadith.label, 'الحديث');
    });

    test('parses every value apiValue can produce', () {
      for (final subject in MemorizationSubject.values) {
        expect(MemorizationSubjectX.fromApi(subject.apiValue), subject);
      }
    });

    test('returns null for null or unrecognised values', () {
      // Read screens pull this off untyped JSON, so a missing or unexpected
      // value must not throw at them — the caller defaults to Quran instead.
      expect(MemorizationSubjectX.fromApi(null), isNull);
      expect(MemorizationSubjectX.fromApi(''), isNull);
      expect(MemorizationSubjectX.fromApi('TAJWEED'), isNull);
    });
  });
}
