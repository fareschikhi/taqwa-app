import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/hadith_label.dart';

void main() {
  group('hadithLabelOrFallback', () {
    test('returns the reference as-is when non-null and non-empty', () {
      expect(hadithLabelOrFallback('حديث النية'), equals('حديث النية'));
    });

    test('returns fallback when reference is null', () {
      expect(hadithLabelOrFallback(null), equals('حديث'));
    });

    test('returns fallback when reference is empty string', () {
      expect(hadithLabelOrFallback(''), equals('حديث'));
    });

    test('returns fallback when reference is whitespace-only', () {
      expect(hadithLabelOrFallback('   '), equals('حديث'));
    });

    test('preserves whitespace when non-empty after trim', () {
      expect(
        hadithLabelOrFallback('  حديث الثلاثة  '),
        equals('  حديث الثلاثة  '),
      );
    });
  });

  group('amountUnitLabel', () {
    test('a Quran entry is always pages', () {
      expect(amountUnitLabel({'subject': 'QURAN'}), 'صفحة');
    });

    test('a hadith entry counted in pages says pages', () {
      expect(amountUnitLabel({'subject': 'HADITH', 'unit': 'PAGE'}), 'صفحة');
    });

    // Rows from before the unit existed carry none, and counted hadiths.
    test('a hadith entry with no unit counts hadiths', () {
      expect(amountUnitLabel({'subject': 'HADITH'}), 'حديث');
      expect(amountUnitLabel({'subject': 'HADITH', 'unit': 'HADITH'}), 'حديث');
    });

    test('a Quran entry counted in ayahs says ayahs', () {
      expect(amountUnitLabel({'subject': 'QURAN', 'unit': 'AYAH'}), 'آية');
    });
  });

  group('recordAmountText', () {
    test('prints pages and hadiths with their unit', () {
      expect(
        recordAmountText({'subject': 'QURAN', 'amountDone': 2.5}),
        '2.5 صفحة',
      );
      expect(
        recordAmountText({'subject': 'HADITH', 'amountDone': 4}),
        '4 حديث',
      );
    });

    test('prints an ayah entry as its range', () {
      expect(
        recordAmountText({
          'subject': 'QURAN',
          'unit': 'AYAH',
          'amountDone': 20,
          'ayahFrom': 1,
          'ayahTo': 20,
        }),
        'الآيات 1–20',
      );
    });

    test('falls back to the count when the range is missing', () {
      expect(
        recordAmountText({'subject': 'QURAN', 'unit': 'AYAH', 'amountDone': 3}),
        '3 آية',
      );
    });
  });
}
