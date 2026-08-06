/// An absent/late attendance row that has no justification attached yet.
///
/// [id] is the attendance row id, which is what a justification links to.
class UnjustifiedAttendanceModel {
  const UnjustifiedAttendanceModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    required this.studentName,
    this.studentAvatar,
  });

  final int id;
  final int studentId;
  final String date;
  final String status;
  final String studentName;
  final String? studentAvatar;

  factory UnjustifiedAttendanceModel.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    final user = student?['user'] as Map<String, dynamic>?;
    return UnjustifiedAttendanceModel(
      id: json['id'] as int,
      studentId: json['studentId'] as int,
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'ABSENT',
      studentName: user?['fullName'] as String? ?? 'غير معروف',
      studentAvatar: user?['avatar'] as String?,
    );
  }

  bool get isLate => status == 'LATE';

  String get statusLabel => isLate ? 'تأخر' : 'غياب';

  String get formattedDate {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return 'غير محدد';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }
}
