import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/core/utils/attendance_queue.dart';

/// Where the pending attendance marks live between attempts.
///
/// Deliberately shared_preferences rather than flutter_secure_storage: the
/// marks are not secrets, and the secure store is Keystore-backed and slower.
class AttendanceQueueStore {
  Future<List<Map<String, dynamic>>> read(int teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(queueKeyFor(teacherId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {
      // A half-written or older payload must not stop the teacher marking.
      return [];
    }
  }

  Future<void> write(int teacherId, List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(queueKeyFor(teacherId), jsonEncode(records));
  }

  Future<void> clear(int teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(queueKeyFor(teacherId));
  }
}
