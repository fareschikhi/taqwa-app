import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/attendance_summary_model.dart';

void main() {
  group('AttendanceSummaryModel', () {
    test('reads the month figures alongside the all-time ones', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 6,
        'absent': 3,
        'late': 1,
        'total': 10,
        'rate': 70,
        'month': 8,
        'monthPresent': 2,
        'monthAbsent': 1,
        'monthLate': 1,
        'monthRate': 75,
      });

      expect(model.present, 6);
      expect(model.absent, 3);
      expect(model.late, 1);
      expect(model.monthPresent, 2);
      expect(model.monthAbsent, 1);
      expect(model.monthLate, 1);
      expect(model.month, 8);
    });

    // The attendance tab shows one حضور box, not one per status: a late day is
    // attendance, so it belongs in the same count as a punctual one.
    test('counts late days as attendance for the month', () {
      final model = AttendanceSummaryModel.fromJson({
        'monthPresent': 2,
        'monthAbsent': 1,
        'monthLate': 3,
      });

      expect(model.monthAttended, 5);
      expect(model.monthMarked, 6);
    });

    // The student endpoint keeps `late` out of `present`, so putting the two
    // back together is what "days he turned up" actually means there.
    test('folds late days into the all-time attended count', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 6,
        'absent': 3,
        'late': 2,
      });

      expect(model.attended, 8);
    });

    // The teacher endpoint has already folded late arrivals into `present` and
    // sends no `late` of its own, so `attended` must not double-count there.
    test('leaves the teacher endpoint figures alone', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 40,
        'absent': 8,
        'month': 9,
      });

      expect(model.attended, 40);
    });

    // The teacher dashboard reads the same model from an endpoint that sends
    // no month breakdown, so the new fields must not throw there.
    test('defaults the month figures when the endpoint omits them', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 5,
        'absent': 3,
        'month': 8,
      });

      expect(model.monthPresent, 0);
      expect(model.monthAbsent, 0);
      expect(model.monthLate, 0);
      expect(model.monthAttended, 0);
      expect(model.monthMarked, 0);
    });

    test('survives a completely empty payload', () {
      final model = AttendanceSummaryModel.fromJson({});

      expect(model.present, 0);
      expect(model.monthAttended, 0);
      expect(model.month, 1);
    });

    test('reads the current streak', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 6,
        'absent': 3,
        'month': 8,
        'currentStreak': 4,
      });

      expect(model.currentStreak, 4);
    });

    // The field was added after the app shipped, so a server that predates it
    // must still parse rather than throw.
    test('a response without a streak reads as zero', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 6,
        'absent': 3,
        'month': 8,
      });

      expect(model.currentStreak, 0);
    });
  });
}
