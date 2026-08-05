/// A single child as returned by GET /parents/:id/children
/// (and nested under ParentModel.children via GET /parents/:id).
class ParentChildModel {
  final int id;
  final String fullName;
  final String? avatar;
  final String? halaqaName;
  final int attendanceCount;
  final int memorizationCount;

  const ParentChildModel({
    required this.id,
    required this.fullName,
    this.avatar,
    this.halaqaName,
    this.attendanceCount = 0,
    this.memorizationCount = 0,
  });

  factory ParentChildModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final halaqa = json['halaqa'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;

    return ParentChildModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (user?['fullName'] as String?) ?? '',
      avatar: user?['avatar'] as String?,
      halaqaName: halaqa?['name'] as String?,
      attendanceCount: (count?['attendance'] as num?)?.toInt() ?? 0,
      memorizationCount: (count?['memorization'] as num?)?.toInt() ?? 0,
    );
  }
}
