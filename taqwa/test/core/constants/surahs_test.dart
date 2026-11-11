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

  group('Surah pages', () {
    test('counts every page a surah appears on', () {
      expect(kSurahs[0].pageCount, 1); // الفاتحة
      expect(kSurahs[1].pageCount, 48); // البقرة, pages 2-49
      expect(kSurahs[113].pageCount, 1); // الناس shares page 604
    });

    // A surah starts on the page the previous one ended on, or the next one,
    // and the mushaf runs from page 1 to page 604 without gaps.
    test('runs through the mushaf in order without gaps', () {
      expect(kSurahs.first.startPage, 1);
      expect(kSurahs.last.endPage, 604);
      for (var i = 0; i < kSurahs.length; i++) {
        final surah = kSurahs[i];
        expect(surah.endPage, greaterThanOrEqualTo(surah.startPage));
        if (i > 0) {
          final gap = surah.startPage - kSurahs[i - 1].endPage;
          expect(gap, inInclusiveRange(0, 1), reason: 'surah ${surah.number}');
        }
      }
    });
  });

  group('Surah ayahs', () {
    test('matches the Hafs count of 6,236 ayahs', () {
      final total = kSurahs.fold<int>(0, (sum, s) => sum + s.ayahCount);
      expect(total, 6236);
    });

    test('knows the ayahs of well-known surahs', () {
      expect(surahOf(1)!.ayahCount, 7);
      expect(surahOf(2)!.ayahCount, 286);
      expect(surahOf(108)!.ayahCount, 3);
      expect(surahOf(114)!.ayahCount, 6);
    });

    test('surahOf returns null outside the mushaf', () {
      expect(surahOf(0), isNull);
      expect(surahOf(null), isNull);
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
