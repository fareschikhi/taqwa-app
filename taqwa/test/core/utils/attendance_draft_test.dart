import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/attendance_draft.dart';
import 'package:taqwa/core/widgets/attendance_controls.dart';

void main() {
  group('pendingAttendanceIds', () {
    test('reports a student the teacher has just marked', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.present},
        saved: {},
      );

      expect(pending, {1});
    });

    test('ignores a student whose chip already matches the server', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.present},
        saved: {1: AttendanceStatus.present},
      );

      expect(pending, isEmpty);
    });

    test('reports a student whose chip was changed after saving', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.absent},
        saved: {1: AttendanceStatus.present},
      );

      expect(pending, {1});
    });

    // Nothing distinguishes "not decided" from "present" once it reaches the
    // server, so an undecided student must never ride along in a batch.
    test('never sends a student the teacher has not decided on', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.unset, 2: AttendanceStatus.late},
        saved: {},
      );

      expect(pending, {2});
    });
  });

  group('attendanceBatchPayload', () {
    test('carries only the pending students, with the shared date', () {
      final payload = attendanceBatchPayload(
        draft: {
          1: AttendanceStatus.present,
          2: AttendanceStatus.present, // already saved
          3: AttendanceStatus.absent,
          4: AttendanceStatus.unset,
        },
        saved: {2: AttendanceStatus.present},
        date: '2026-08-28',
      );

      expect(payload, [
        {'studentId': 1, 'date': '2026-08-28', 'status': 'PRESENT'},
        {'studentId': 3, 'date': '2026-08-28', 'status': 'ABSENT'},
      ]);
    });

    test('is empty when nothing changed', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.late},
        saved: {1: AttendanceStatus.late},
        date: '2026-08-28',
      );

      expect(payload, isEmpty);
    });
  });

  group('status mapping', () {
    test('round-trips every real status', () {
      for (final status in [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.late,
      ]) {
        expect(attendanceStatusFromApi(attendanceStatusToApi(status)), status);
      }
    });

    test('has no wire spelling for an undecided chip', () {
      expect(attendanceStatusToApi(AttendanceStatus.unset), isNull);
    });

    test('reads an unknown or missing status as undecided', () {
      expect(attendanceStatusFromApi(null), AttendanceStatus.unset);
      expect(attendanceStatusFromApi('EXCUSED'), AttendanceStatus.unset);
    });
  });

  group('missed memorization', () {
    // The toggle changes without the chip changing, and the old comparison
    // looked only at the chip — so this edit would never have been sent.
    test('reports a student whose toggle changed but whose chip did not', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.present},
        saved: {1: AttendanceStatus.present},
        missedDraft: {1: true},
        missedSaved: {1: false},
      );

      expect(pending, {1});
    });

    test('ignores a student whose toggle already matches the server', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.present},
        saved: {1: AttendanceStatus.present},
        missedDraft: {1: true},
        missedSaved: {1: true},
      );

      expect(pending, isEmpty);
    });

    test('never sends an undecided student even when the toggle changed', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.unset},
        saved: {},
        missedDraft: {1: true},
        missedSaved: {},
      );

      expect(pending, isEmpty);
    });

    test('carries the flag for an adult student', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.present},
        saved: {},
        date: '2026-08-28',
        missedDraft: {1: true},
      );

      expect(payload, [
        {
          'studentId': 1,
          'date': '2026-08-28',
          'status': 'PRESENT',
          'missedMemorization': true,
        },
      ]);
    });

    // Unlike absence, lateness does not absorb the missed recitation: the
    // server's desiredCharges stacks LATE and MISSED_MEMORIZATION on the same
    // day, so both have to survive the trip in one record.
    test('carries the flag for a late adult who also did not recite', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.late},
        saved: {},
        date: '2026-08-28',
        missedDraft: {1: true},
      );

      expect(payload, [
        {
          'studentId': 1,
          'date': '2026-08-28',
          'status': 'LATE',
          'missedMemorization': true,
        },
      ]);
    });

    // A child student never accrues a fine, so the key is left off entirely
    // rather than sent as a meaningless false.
    test('omits the flag for a student who is not in the adult map', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.present},
        saved: {},
        date: '2026-08-28',
      );

      expect(payload.first.containsKey('missedMemorization'), isFalse);
    });
  });
}
