import '../widgets/attendance_chip.dart';

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

/// Students whose chip or memorization toggle no longer matches the row the
/// server confirmed.
///
/// The teacher marks a whole halaqa before saving, so this is what separates
/// the edits that still need writing from the ones already on the server.
/// The toggle is compared alongside the chip because it changes on its own:
/// marking an adult student as not having recited leaves his chip on present,
/// and a chip-only comparison would drop the edit silently.
Set<int> pendingAttendanceIds({
  required Map<int, AttendanceStatus> draft,
  required Map<int, AttendanceStatus> saved,
  Map<int, bool> missedDraft = const {},
  Map<int, bool> missedSaved = const {},
}) {
  return {
    for (final entry in draft.entries)
      // An undecided student has no status to send, so no toggle can rescue
      // him into the batch.
      if (entry.value != AttendanceStatus.unset &&
          (saved[entry.key] != entry.value ||
              (missedDraft[entry.key] ?? false) !=
                  (missedSaved[entry.key] ?? false)))
        entry.key,
  };
}

/// The `records` array for `POST /attendance/batch`, one entry per pending
/// student. Ordering follows [draft] so a failure reads against the list the
/// teacher was looking at.
///
/// [missedDraft] holds only the adult students on the sheet: a child never
/// accrues a fine, so his record leaves the key off entirely.
List<Map<String, dynamic>> attendanceBatchPayload({
  required Map<int, AttendanceStatus> draft,
  required Map<int, AttendanceStatus> saved,
  required String date,
  Map<int, bool> missedDraft = const {},
  Map<int, bool> missedSaved = const {},
}) {
  final pending = pendingAttendanceIds(
    draft: draft,
    saved: saved,
    missedDraft: missedDraft,
    missedSaved: missedSaved,
  );
  return [
    for (final entry in draft.entries)
      if (pending.contains(entry.key))
        {
          'studentId': entry.key,
          'date': date,
          'status': attendanceStatusToApi(entry.value)!,
          if (missedDraft.containsKey(entry.key))
            'missedMemorization': missedDraft[entry.key]!,
        },
  ];
}
