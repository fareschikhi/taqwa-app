/// Lightweight student model for teacher-facing lists.
/// Backend returns this from GET /students?teacherId=...
class TeacherStudentModel {
  final int id;
  final String fullName;
  final String? avatar;
  final bool isActive;
  final int? teacherId;

  const TeacherStudentModel({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.isActive,
    this.teacherId,
  });

  factory TeacherStudentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TeacherStudentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (user?['fullName'] as String?) ?? (json['fullName'] as String?) ?? '',
      avatar: (user?['avatar'] as String?) ?? (json['avatar'] as String?),
      isActive: (user?['isActive'] as bool?) ?? (json['isActive'] as bool?) ?? true,
      teacherId: (json['teacherId'] as num?)?.toInt(),
    );
  }
}

/// Paginated response wrapper for student list.
class StudentListResponse {
  final List<TeacherStudentModel> data;
  final int total;
  final int page;
  final int limit;

  const StudentListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory StudentListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? [];
    return StudentListResponse(
      data: rawData.map((e) => TeacherStudentModel.fromJson(e as Map<String, dynamic>)).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
    );
  }

  bool get hasMore => data.length < total;
}
