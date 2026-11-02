import '../widgets/attendance_controls.dart';

/// The API's spelling of a chip, or null when there is nothing to send.
///
/// `unset` is the teacher not having decided yet. An attendance row has no way
/// to express that — every row is present, absent or late — so it is dropped
/// rather than defaulted, which would silently mark a whole halaqa present.
String? attendanceStatusToApi(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'PRESENT',
  AttendanceStatus.absent => 'ABSENT',
  AttendanceStatus.late => 'LATE',
  AttendanceStatus.unset => null,
};

/// Parses the API's spelling back into a chip.
AttendanceStatus attendanceStatusFromApi(String? value) =>
    switch (value?.toUpperCase()) {
      'PRESENT' => AttendanceStatus.present,
      'ABSENT' => AttendanceStatus.absent,
      'LATE' => AttendanceStatus.late,
      _ => AttendanceStatus.unset,
    };

/// Students whose chip no longer matches the row the server confirmed.
///
/// The teacher marks a whole halaqa before saving, so this is what separates
/// the edits that still need writing from the ones already on the server.
///
/// There is deliberately no "did not memorize" input here: the server derives
/// it from whether a recitation was recorded that day.
Set<int> pendingAttendanceIds({
  required Map<int, AttendanceStatus> draft,
  required Map<int, AttendanceStatus> saved,
}) {
  return {
    for (final entry in draft.entries)
      // An undecided student has no status to send.
      if (entry.value != AttendanceStatus.unset &&
          saved[entry.key] != entry.value)
        entry.key,
  };
}

/// The `records` array for `POST /attendance/batch`, one entry per pending
/// student. Ordering follows [draft] so a failure reads against the list the
/// teacher was looking at.
List<Map<String, dynamic>> attendanceBatchPayload({
  required Map<int, AttendanceStatus> draft,
  required Map<int, AttendanceStatus> saved,
  required String date,
}) {
  final pending = pendingAttendanceIds(draft: draft, saved: saved);
  return [
    for (final entry in draft.entries)
      if (pending.contains(entry.key))
        {
          'studentId': entry.key,
          'date': date,
          'status': attendanceStatusToApi(entry.value)!,
        },
  ];
}
