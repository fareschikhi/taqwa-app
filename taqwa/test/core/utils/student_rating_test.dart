import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/student_rating.dart';

void main() {
  group('ratingOf', () {
    test('returns the rating a teacher typed', () {
      expect(ratingOf({'currentRating': 'ممتاز'}), equals('ممتاز'));
    });

    test('trims surrounding spaces', () {
      expect(ratingOf({'currentRating': '  جيد جداً '}), equals('جيد جداً'));
    });

    test('reads a cleared (empty) rating as unset', () {
      expect(ratingOf({'currentRating': ''}), isNull);
      expect(ratingOf({'currentRating': '   '}), isNull);
    });

    test('is null when the profile has no rating or failed to load', () {
      expect(ratingOf({'currentRating': null}), isNull);
      expect(ratingOf(<String, dynamic>{}), isNull);
      expect(ratingOf(null), isNull);
    });
  });
}
