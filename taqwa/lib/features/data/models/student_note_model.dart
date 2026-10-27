class StudentNoteModel {
  final int id;
  final int studentId;
  final int teacherId;
  final String note;
  final String createdAt;
  final String? studentName;
  final String? studentAvatar;
  final String? teacherName;
  // Everyone the note is addressed to. On a student's own page this is just
  // that student; the teacher sees the whole list. studentId/studentName are
  // its first entry.
  final List<int> recipientIds;

  const StudentNoteModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.note,
    required this.createdAt,
    this.studentName,
    this.studentAvatar,
    this.teacherName,
    this.recipientIds = const [],
  });

  /// Sent to several students at once ("all students" on the teacher's page).
  bool get isBulk => recipientIds.length > 1;

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
      recipientIds: ((json['recipients'] as List?) ?? const [])
          .map((r) => ((r as Map<String, dynamic>)['studentId'] as num).toInt())
          .toList(),
    );
  }
}
