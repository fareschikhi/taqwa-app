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

      expect(model.rate, 70);
      expect(model.monthRate, 75);
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
    });

    // The teacher dashboard reads the same model from an endpoint that sends
    // no month breakdown, so the new fields must not throw there.
    test('defaults the month figures when the endpoint omits them', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 5,
        'absent': 3,
        'rate': 63,
        'month': 8,
      });

      expect(model.monthPresent, 0);
      expect(model.monthAbsent, 0);
      expect(model.monthLate, 0);
      expect(model.monthAttended, 0);
      expect(model.monthRate, 0);
    });

    test('survives a completely empty payload', () {
      final model = AttendanceSummaryModel.fromJson({});

      expect(model.rate, 0);
      expect(model.monthRate, 0);
      expect(model.monthAttended, 0);
    });

    test('reads the current streak', () {
      final model = AttendanceSummaryModel.fromJson({
        'present': 6,
        'absent': 3,
        'rate': 70,
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
        'rate': 70,
        'month': 8,
      });

      expect(model.currentStreak, 0);
    });
  });
}
