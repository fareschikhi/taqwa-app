import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/memorization_progress_summary_model.dart';

void main() {
  group('MemorizationProgressSummaryModel.fromJson', () {
    test('reads the three stage counts and the halaqa size', () {
      final summary = MemorizationProgressSummaryModel.fromJson(const {
        'memorizingCount': 7,
        'minorReviewCount': 4,
        'majorReviewCount': 1,
        'studentsCount': 12,
      });

      expect(summary.memorizingCount, 7);
      expect(summary.minorReviewCount, 4);
      expect(summary.majorReviewCount, 1);
      expect(summary.studentsCount, 12);
    });

    // A teacher with no students at all gets zeros rather than a throw, the
    // same shape the server sends for an empty halaqa.
    test('reads an empty payload as zeros', () {
      final summary = MemorizationProgressSummaryModel.fromJson(const {});

      expect(summary.memorizingCount, 0);
      expect(summary.studentsCount, 0);
    });

    // An older server sends percentages under different keys. Reading those as
    // zero is the honest outcome: a share cannot be turned back into a count.
    test('ignores the percentages an older server sends', () {
      final summary = MemorizationProgressSummaryModel.fromJson(const {
        'memorizationPercent': 58,
        'minorReviewPercent': 33,
        'majorReviewPercent': 9,
      });

      expect(summary.memorizingCount, 0);
      expect(summary.minorReviewCount, 0);
      expect(summary.majorReviewCount, 0);
    });
  });
}
