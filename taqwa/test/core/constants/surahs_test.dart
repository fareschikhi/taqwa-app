import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/constants/surahs.dart';

void main() {
  group('surahNameOf', () {
    test('names a surah from its number', () {
      expect(surahNameOf(2), 'البقرة');
      expect(surahNameOf(114), 'الناس');
    });

    // Read screens pull the number off untyped JSON, so an unusable value must
    // cost the name rather than throw.
    test('returns null outside the mushaf', () {
      expect(surahNameOf(0), isNull);
      expect(surahNameOf(115), isNull);
      expect(surahNameOf(null), isNull);
    });

    test('covers every surah of the mushaf exactly once', () {
      expect(kSurahs, hasLength(114));
      expect(kSurahs.map((s) => s.number).toSet(), hasLength(114));

      for (var number = 1; number <= 114; number++) {
        expect(surahNameOf(number), isNotEmpty, reason: 'surah $number');
      }
    });
  });

  group('surahLabelOf', () {
    test('labels a known surah by name', () {
      expect(surahLabelOf(2), 'سورة البقرة');
    });

    // A bad row should still read as an entry rather than a blank.
    test('falls back to the number outside the mushaf', () {
      expect(surahLabelOf(0), 'سورة رقم 0');
      expect(surahLabelOf(null), 'سورة رقم -');
    });
  });
}
