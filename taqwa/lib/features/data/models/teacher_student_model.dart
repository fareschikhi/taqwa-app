/// Lightweight student model for teacher-facing lists.
/// Backend returns this from GET /students?teacherId=...
class TeacherStudentModel {
  final int id;
  final String fullName;
  final String? avatar;
  final bool isActive;
  final int? teacherId;

  /// The halaqa this student is enrolled in, when the server returned one.
  /// `GET /students` nests it as `{ halaqa: { id, ... } }`; a student with no
  /// halaqa yet (or an older payload) simply has no id to read here, and
  /// nothing downstream can treat him as belonging to an adults' halaqa.
  final int? halaqaId;
  // Admin opt-in: whether this student's recitation sheet offers a Hadith
  // subject alongside Quran.
  final bool tracksHadith;

  const TeacherStudentModel({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.isActive,
    this.teacherId,
    this.halaqaId,
    this.tracksHadith = false,
  });

  factory TeacherStudentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final halaqa = json['halaqa'] as Map<String, dynamic>?;
    return TeacherStudentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (user?['fullName'] as String?) ?? (json['fullName'] as String?) ?? '',
      avatar: (user?['avatar'] as String?) ?? (json['avatar'] as String?),
      isActive: (user?['isActive'] as bool?) ?? (json['isActive'] as bool?) ?? true,
      teacherId: (json['teacherId'] as num?)?.toInt(),
      halaqaId: (halaqa?['id'] as num?)?.toInt() ?? (json['halaqaId'] as num?)?.toInt(),
      tracksHadith: (json['tracksHadith'] as bool?) ?? false,
    );
  }

  /// The flat shape [TeacherStudentModel.fromJson] already falls back to, so
  /// a roster saved on the phone reads back through the same parser.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'fullName': fullName,
    'avatar': avatar,
    'isActive': isActive,
    'teacherId': teacherId,
    'halaqaId': halaqaId,
    'tracksHadith': tracksHadith,
  };
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
