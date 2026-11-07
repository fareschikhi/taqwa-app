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
      expect(hadithLabelOrFallback('  حديث الثلاثة  '), equals('  حديث الثلاثة  '));
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
  });
}
