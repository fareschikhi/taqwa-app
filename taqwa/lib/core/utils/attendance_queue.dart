/// Attendance marks that failed to reach the server, held until a retry.
///
/// The records are exactly what `attendanceBatchPayload` produces, so the
/// queue and the live save speak one language and a flush is just another
/// batch submission.
library;

/// Where one teacher's queue is stored. The id is in the key because a device
/// shared by two teachers must never flush one teacher's marks under the
/// other's token — the records carry no teacher, the server infers it from
/// the auth header.
String queueKeyFor(int teacherId) => 'pending_attendance_$teacherId';

/// Folds [incoming] into [existing], last write winning per student and date.
///
/// A teacher who marks present, fails to save, then corrects to absent must
/// send only the correction. An updated record keeps its original position so
/// a retry reads in the order the halaqa was marked.
List<Map<String, dynamic>> mergeQueued(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  String identity(Map<String, dynamic> r) => '${r['studentId']}@${r['date']}';

  final merged = [...existing];
  for (final record in incoming) {
    final at = merged.indexWhere((r) => identity(r) == identity(record));
    if (at == -1) {
      merged.add(record);
    } else {
      merged[at] = record;
    }
  }
  return merged;
}
