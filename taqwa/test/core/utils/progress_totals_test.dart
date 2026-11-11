import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/progress_totals.dart';

void main() {
  group('quranTotals', () {
    test('shows pages alone for a student who only records pages', () {
      expect(totalsText(quranTotals(pages: 12, ayahs: 0)), '12 صفحة');
    });

    test('shows pages and ayahs side by side, never added', () {
      expect(
        totalsText(quranTotals(pages: 2.5, ayahs: 40)),
        '2.5 صفحة · 40 آية',
      );
    });

    test('drops the zero pages of a student recorded only by ayahs', () {
      expect(totalsText(quranTotals(pages: 0, ayahs: 40)), '40 آية');
    });

    test('still reads 0 pages with nothing recorded', () {
      expect(totalsText(quranTotals()), '0 صفحة');
    });
  });

  group('hadithTotals', () {
    test('defaults to hadiths', () {
      expect(totalsText(hadithTotals()), '0 حديث');
    });

    test('shows hadiths and hadith pages apart', () {
      expect(totalsText(hadithTotals(hadiths: 4, pages: 2)), '4 حديث · 2 صفحة');
      expect(totalsText(hadithTotals(pages: 1.5)), '1.5 صفحة');
    });
  });

  test('totalsText can put each unit on its own line', () {
    expect(
      totalsText(quranTotals(pages: 3, ayahs: 7), separator: '\n'),
      '3 صفحة\n7 آية',
    );
  });
}
