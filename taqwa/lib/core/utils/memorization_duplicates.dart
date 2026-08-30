import '../constants/surahs.dart';
import '../enums/memorization_type.dart';

/// Helpers for spotting a student who already has recitation recorded today.
///
/// The server appends every entry: `POST /memorization` inserts a row, and
/// `memorization_progress` carries no unique constraint on (student, date).
/// A second entry therefore adds to the day rather than replacing it, which is
/// fine for a teacher recording حفظ and then مراجعة, and a silent mistake for a
/// teacher who simply forgot they had already recorded this student.

/// The day's records grouped by student id, preserving the order they arrived
/// in. Records with no usable id are dropped: they cannot be attributed to the
/// student the teacher is about to record.
Map<int, List<Map<String, dynamic>>> memorizationByStudent(
  List<Map<String, dynamic>> records,
) {
  final grouped = <int, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final studentId = (record['studentId'] as num?)?.toInt();
    if (studentId == null) continue;
    grouped.putIfAbsent(studentId, () => []).add(record);
  }
  return grouped;
}

/// One line describing a record, e.g. `سورة الأعراف · حفظ جديد · 2 صفحة`.
///
/// Used to show the teacher exactly what is already on file, so the warning
/// names the work rather than just asserting that some exists.
String memorizationSummary(Map<String, dynamic> record) {
  // An unrecognised type falls back to new memorization, matching the column
  // default on the server.
  final type =
      MemorizationTypeX.fromApi(record['memorizationType'] as String?) ??
      MemorizationType.hifz;
  final typeLabel = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
  final surah = surahLabelOf((record['surahNumber'] as num?)?.toInt());
  final amount = (record['amountDone'] as num?)?.toInt() ?? 0;

  return '$surah · $typeLabel · $amount ${type.unitLabel}';
}
