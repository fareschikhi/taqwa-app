import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/ayah_range.dart';

void main() {
  group('ayahRangeError', () {
    test('accepts a range inside the surah', () {
      expect(ayahRangeError(from: 1, to: 20, ayahCount: 286), isNull);
      expect(ayahRangeError(from: 7, to: 7, ayahCount: 7), isNull);
    });

    test('asks for both ends', () {
      expect(ayahRangeError(from: 1, to: null, ayahCount: 7), isNotNull);
      expect(ayahRangeError(from: null, to: 3, ayahCount: 7), isNotNull);
    });

    test('refuses an ayah past the end of the surah', () {
      expect(ayahRangeError(from: 1, to: 8, ayahCount: 7), contains('7'));
      expect(ayahRangeError(from: 0, to: 3, ayahCount: 7), isNotNull);
    });

    test('refuses a backwards range', () {
      expect(ayahRangeError(from: 10, to: 5, ayahCount: 286), isNotNull);
    });
  });

  test('ayahCountIn counts both ends', () {
    expect(ayahCountIn(1, 20), 20);
    expect(ayahCountIn(5, 5), 1);
  });

  group('nextAyahRange', () {
    test('continues after last session with the same length', () {
      expect(nextAyahRange(lastFrom: 1, lastTo: 10, ayahCount: 286), (
        from: 11,
        to: 20,
      ));
    });

    test('stops at the end of the surah', () {
      expect(nextAyahRange(lastFrom: 1, lastTo: 5, ayahCount: 7), (
        from: 6,
        to: 7,
      ));
    });

    // Nothing comes after the last ayah, so the range is offered again.
    test('repeats a range that already reached the end', () {
      expect(nextAyahRange(lastFrom: 4, lastTo: 7, ayahCount: 7), (
        from: 4,
        to: 7,
      ));
    });
  });

  test('ayahRangeLabel names one ayah or a range', () {
    expect(ayahRangeLabel(5, 5), 'الآية 5');
    expect(ayahRangeLabel(1, 20), 'الآيات 1–20');
  });
}
