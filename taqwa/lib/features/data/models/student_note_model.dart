class StudentNoteModel {
  final int id;
  final int studentId;
  final int teacherId;
  final String note;
  final String createdAt;
  final String? studentName;
  final String? studentAvatar;
  final String? teacherName;

  const StudentNoteModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.note,
    required this.createdAt,
    this.studentName,
    this.studentAvatar,
    this.teacherName,
  });

  factory StudentNoteModel.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    final studentUser = student?['user'] as Map<String, dynamic>?;
    final teacher = json['teacher'] as Map<String, dynamic>?;
    final teacherUser = teacher?['user'] as Map<String, dynamic>?;

    return StudentNoteModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['studentId'] as num?)?.toInt() ?? 0,
      teacherId: (json['teacherId'] as num?)?.toInt() ?? 0,
      note: (json['note'] as String?) ?? '',
      createdAt: (json['createdAt'] as String?) ?? '',
      studentName: studentUser?['fullName'] as String?,
      studentAvatar: studentUser?['avatar'] as String?,
      teacherName: teacherUser?['fullName'] as String?,
    );
  }
}
