import 'package:dio/dio.dart';

/// Reason code the API attaches when attendance is what blocked the write.
/// Mirrors `MEMORIZATION_ERROR.STUDENT_ABSENT` in the backend.
const String kStudentAbsentCode = 'STUDENT_ABSENT';

const String _genericFailure = 'فشل حفظ التسميع';

/// The message the teacher sees when saving a recitation fails.
///
/// Every rejection on this route arrives as a 400: an over-large amount, a
/// malformed payload and a genuinely absent student are indistinguishable from
/// the status line alone. Blaming attendance for all of them sent teachers to
/// the attendance chips over faults that had nothing to do with attendance, so
/// only the server's explicit reason code is allowed to claim that cause.
String memorizationErrorMessage(Object error) {
  if (error is! DioException) return _genericFailure;

  final data = error.response?.data;
  if (data is Map && data['code'] == kStudentAbsentCode) {
    return 'لا يمكن تسجيل التسميع لطالب مسجَّل كغائب';
  }

  // Transport failures are already worded by the error interceptor, and it
  // distinguishes a slow server from an unreachable one. Reusing its text
  // keeps a dropped connection reading the same here as everywhere else.
  if (error.response == null) {
    final translated = error.error;
    if (translated is String && translated.isNotEmpty) return translated;
  }

  return _genericFailure;
}
