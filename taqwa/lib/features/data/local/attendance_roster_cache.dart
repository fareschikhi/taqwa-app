import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';

/// The last attendance sheet the server handed this teacher, kept so the page
/// still opens when the phone has no signal or the server is down.
///
/// Rewritten on every successful load rather than on a schedule: a copy is
/// only ever read when the network fails, so the freshest one is always the
/// right one to keep.
class AttendanceRosterCache {
  AttendanceRosterCache({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Per teacher, for the same reason as the queue: a shared phone must not
  /// show one teacher the other's halaqa.
  static String keyFor(int teacherId) => 'attendance_roster_$teacherId';

  Future<void> write(
    int teacherId, {
    required String date,
    required List<TeacherStudentModel> students,
    required List<HalaqaModel> halaqas,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> memorization,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(teacherId),
      jsonEncode({
        'savedAt': _now().toIso8601String(),
        'date': date,
        'students': students.map((s) => s.toCacheJson()).toList(),
        'halaqas': halaqas.map((h) => h.toCacheJson()).toList(),
        'attendance': attendance,
        'memorization': memorization,
      }),
    );
  }

  /// Null when nothing usable is stored. The day's attendance and
  /// memorization come back empty unless they were saved for [date]:
  /// yesterday's marks shown as today's would be saved over today's rows.
  Future<AttendanceRoster?> read(int teacherId, {required String date}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(teacherId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final sameDay = json['date'] == date;
      List<Map<String, dynamic>> rows(String key) => (json[key] as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

      return AttendanceRoster(
        savedAt: DateTime.parse(json['savedAt'] as String),
        students: rows('students').map(TeacherStudentModel.fromJson).toList(),
        halaqas: rows('halaqas').map(HalaqaModel.fromJson).toList(),
        attendance: sameDay ? rows('attendance') : [],
        memorization: sameDay ? rows('memorization') : [],
      );
    } catch (_) {
      // A half-written or older copy must not stop the page opening; it just
      // behaves as if nothing were cached.
      return null;
    }
  }
}

/// One teacher's attendance sheet for a day, whether it just came from the
/// server or was read back from the phone. [savedAt] is when the server sent
/// it, which is what the offline notice reports.
class AttendanceRoster {
  const AttendanceRoster({
    required this.savedAt,
    required this.students,
    required this.halaqas,
    required this.attendance,
    required this.memorization,
  });

  final DateTime savedAt;
  final List<TeacherStudentModel> students;
  final List<HalaqaModel> halaqas;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> memorization;
}
