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

  group('teacher-chosen late fee', () {
    test('rides along on a late record', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.late},
        saved: {},
        date: '2026-08-28',
        lateFees: {1: 25},
      );

      expect(payload, [
        {'studentId': 1, 'date': '2026-08-28', 'status': 'LATE', 'lateFee': 25},
      ]);
    });

    test('sends 0 to waive the fee rather than dropping it', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.late},
        saved: {},
        date: '2026-08-28',
        lateFees: {1: 0},
      );

      expect(payload.single['lateFee'], 0);
    });

    test('is never sent on a status that is not late', () {
      final payload = attendanceBatchPayload(
        draft: {1: AttendanceStatus.present},
        saved: {},
        date: '2026-08-28',
        lateFees: {1: 25},
      );

      expect(payload.single.containsKey('lateFee'), isFalse);
    });

    // Already late on the server, re-marked at a new price: still a change.
    test('makes an already-saved late student pending again', () {
      final pending = pendingAttendanceIds(
        draft: {1: AttendanceStatus.late},
        saved: {1: AttendanceStatus.late},
        lateFees: {1: 5},
      );

      expect(pending, {1});
    });
  });

  group('status mapping', () {
    test('round-trips every real status', () {
      for (final status in [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.late,
        AttendanceStatus.excused,
      ]) {
        expect(attendanceStatusFromApi(attendanceStatusToApi(status)), status);
      }
    });

    test('sends عذر as EXCUSED', () {
      expect(attendanceStatusToApi(AttendanceStatus.excused), 'EXCUSED');
    });

    test('has no wire spelling for an undecided chip', () {
      expect(attendanceStatusToApi(AttendanceStatus.unset), isNull);
    });

    test('reads an unknown or missing status as undecided', () {
      expect(attendanceStatusFromApi(null), AttendanceStatus.unset);
      expect(attendanceStatusFromApi('HOLIDAY'), AttendanceStatus.unset);
    });
  });

  group('isAway', () {
    // Both keep the student out of recitation; only absent counts against him.
    test('is true for absent and excused only', () {
      expect(AttendanceStatus.absent.isAway, isTrue);
      expect(AttendanceStatus.excused.isAway, isTrue);
      expect(AttendanceStatus.present.isAway, isFalse);
      expect(AttendanceStatus.late.isAway, isFalse);
      expect(AttendanceStatus.unset.isAway, isFalse);
    });
  });

  // "Did not memorize" is derived by the server from whether a recitation
  // was recorded that day, so the sheet never sends it — an adult student
  // marked present goes out exactly like a child.
  test('never sends a missedMemorization flag', () {
    final payload = attendanceBatchPayload(
      draft: {1: AttendanceStatus.present, 2: AttendanceStatus.late},
      saved: {},
      date: '2026-08-28',
    );

    expect(payload, [
      {'studentId': 1, 'date': '2026-08-28', 'status': 'PRESENT'},
      {'studentId': 2, 'date': '2026-08-28', 'status': 'LATE'},
    ]);
  });
}
