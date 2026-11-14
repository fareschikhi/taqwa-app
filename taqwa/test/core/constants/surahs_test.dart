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
    });

    // The surah is optional: an entry may record only an amount.
    test('names an entry without a surah after the Quran', () {
      expect(surahLabelOf(null), kNoSurahLabel);
    });
  });

  group('pagesCoveredBy', () {
    // الإخلاص، الفلق and الناس all sit on page 604: three surahs, one page.
    test('counts a page shared by several surahs once', () {
      expect(pagesCoveredBy([112, 113, 114]), 1);
    });

    test('adds the pages of surahs that do not touch', () {
      // الفاتحة (1) + البقرة (2–49).
      expect(pagesCoveredBy([1, 2]), 49);
    });

    test('counts the overlap of neighbours once', () {
      // النساء 77–106 and المائدة 106–127 share page 106.
      expect(pagesCoveredBy([4, 5]), 51);
    });

    test('ignores numbers outside the mushaf and reads none as zero', () {
      expect(pagesCoveredBy([0, 115]), 0);
      expect(pagesCoveredBy(const []), 0);
    });
  });

  group('surahNumbersOfRecord', () {
    test('reads the list of a several-surah entry', () {
      expect(
        surahNumbersOfRecord({
          'surahNumber': 112,
          'surahNumbers': [112, 113, 114],
        }),
        [112, 113, 114],
      );
    });

    // Every entry recorded before the list existed has only surahNumber.
    test('falls back to the single surahNumber', () {
      expect(surahNumbersOfRecord({'surahNumber': 2}), [2]);
      expect(surahNumbersOfRecord({'surahNumber': 2, 'surahNumbers': null}), [
        2,
      ]);
    });

    test('reads an entry without a surah as none', () {
      expect(surahNumbersOfRecord({'surahNumber': null}), isEmpty);
    });

    test('skips values that are not surah numbers', () {
      expect(
        surahNumbersOfRecord({
          'surahNumber': 113,
          'surahNumbers': [113, 'x', 114],
        }),
        [113, 114],
      );
    });
  });

  group('surahsLabelOf', () {
    test('names one surah the way surahLabelOf does', () {
      expect(surahsLabelOf([2]), 'سورة البقرة');
    });

    test('names every surah of a several-surah entry', () {
      expect(surahsLabelOf([112, 113, 114]), 'سور الإخلاص، الفلق، الناس');
    });

    test('names an entry without a surah after the Quran', () {
      expect(surahsLabelOf(const []), kNoSurahLabel);
    });
  });

  group('recordSurahLabel', () {
    test('names all the surahs of a stored entry', () {
      expect(
        recordSurahLabel({
          'surahNumber': 113,
          'surahNumbers': [113, 114],
        }),
        'سور الفلق، الناس',
      );
    });

    test('keeps naming a single-surah entry as before', () {
      expect(recordSurahLabel({'surahNumber': 18}), 'سورة الكهف');
    });
  });
}
