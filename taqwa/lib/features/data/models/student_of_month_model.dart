import 'package:taqwa/core/utils/points_format.dart';

/// Arabic month names as used in Algeria (جانفي, فيفري ...), indexed 1–12.
const List<String> kArabicMonths = [
  '',
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// "2026-11" → "نوفمبر 2026". Falls back to the key itself if it is malformed.
String monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return key;
  return '${kArabicMonths[month]} $year';
}

/// A validated طالب الشهر, as a dashboard shows it. Carries no score: the
/// server keeps classmates' points private.
class StudentOfMonthModel {
  final int halaqaId;
  final String halaqaName;

  /// The month whose points were counted, "YYYY-MM".
  final String month;
  final int studentId;
  final String fullName;
  final String? avatar;

  const StudentOfMonthModel({
    required this.halaqaId,
    required this.halaqaName,
    required this.month,
    required this.studentId,
    required this.fullName,
    this.avatar,
  });

  String get monthName => monthLabel(month);

  factory StudentOfMonthModel.fromJson(Map<String, dynamic> json) {
    final student = Map<String, dynamic>.from(json['student'] as Map);
    return StudentOfMonthModel(
      halaqaId: (json['halaqaId'] as num).toInt(),
      halaqaName: json['halaqaName'] as String? ?? '',
      month: json['month'] as String? ?? '',
      studentId: (student['id'] as num).toInt(),
      fullName: student['fullName'] as String? ?? '',
      avatar: student['avatar'] as String?,
    );
  }
}

/// One student in the teacher's picker, with the month's figures.
class StudentOfMonthCandidate {
  final int studentId;
  final String fullName;
  final String? avatar;
  final num points;
  final int finesPenalty;
  final num score;

  /// Has the month's highest score (several can, on a tie).
  final bool isTop;

  const StudentOfMonthCandidate({
    required this.studentId,
    required this.fullName,
    required this.points,
    required this.finesPenalty,
    required this.score,
    required this.isTop,
    this.avatar,
  });

  factory StudentOfMonthCandidate.fromJson(Map<String, dynamic> json) =>
      StudentOfMonthCandidate(
        studentId: (json['studentId'] as num).toInt(),
        fullName: json['fullName'] as String? ?? '',
        avatar: json['avatar'] as String?,
        points: parsePoints(json['points']),
        finesPenalty: (json['finesPenalty'] as num?)?.toInt() ?? 0,
        score: parsePoints(json['score']),
        isTop: json['isTop'] == true,
      );
}

/// A halaqa still waiting for its teacher to validate last month's pick.
class PendingStudentOfMonth {
  final int halaqaId;
  final String halaqaName;
  final String month;

  /// Best first, as the server ranks them.
  final List<StudentOfMonthCandidate> candidates;

  const PendingStudentOfMonth({
    required this.halaqaId,
    required this.halaqaName,
    required this.month,
    required this.candidates,
  });

  String get monthName => monthLabel(month);

  List<StudentOfMonthCandidate> get top =>
      candidates.where((c) => c.isTop).toList();

  List<StudentOfMonthCandidate> get others =>
      candidates.where((c) => !c.isTop).toList();

  factory PendingStudentOfMonth.fromJson(Map<String, dynamic> json) =>
      PendingStudentOfMonth(
        halaqaId: (json['halaqaId'] as num).toInt(),
        halaqaName: json['halaqaName'] as String? ?? '',
        month: json['month'] as String? ?? '',
        candidates: ((json['candidates'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (c) => StudentOfMonthCandidate.fromJson(
                Map<String, dynamic>.from(c),
              ),
            )
            .toList(),
      );
}
