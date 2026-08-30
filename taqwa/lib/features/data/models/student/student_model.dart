class StudentModel {
  final int? id;
  final int? userId;
  final String fullName;
  final String? phone;
  final String birthDate;
  final String address;
  final int? halaqaId;
  final int? parentId;
  final String? avatar;
  final bool? isActive;

  /// True for a student who is his own guardian — he logs in with a real
  /// password and carries no parent. Comes from the nested `user.role`
  /// (`ADULT_STUDENT` vs `STUDENT`); defaults to false so a student picker
  /// reading an older or role-less payload treats him as a child rather than
  /// guessing wrong in the direction that could enrol him where he does not
  /// belong.
  final bool isAdult;

  const StudentModel({
    this.id,
    this.userId,
    required this.fullName,
    this.phone,
    this.birthDate = '',
    this.address = '',
    this.halaqaId,
    this.parentId,
    this.avatar,
    this.isActive,
    this.isAdult = false,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : null;
    final studentMap = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : null;

    final String birthDateRaw =
        json['birthDate']?.toString() ??
        studentMap?['birthDate']?.toString() ??
        '';
    final String addressRaw =
        json['address']?.toString() ?? studentMap?['address']?.toString() ?? '';

    return StudentModel(
      id: (json['id'] as num?)?.toInt() ?? (studentMap?['id'] as num?)?.toInt(),
      userId: (userMap?['id'] as num?)?.toInt(),
      fullName:
          (json['fullName'] as String?) ??
          (userMap?['fullName'] as String?) ??
          '',
      phone: (json['phone'] as String?) ?? (userMap?['phone'] as String?),
      birthDate: birthDateRaw,
      address: addressRaw,
      halaqaId:
          (json['halaqaId'] as num?)?.toInt() ??
          (studentMap?['halaqaId'] as num?)?.toInt(),
      parentId:
          (json['parentId'] as num?)?.toInt() ??
          (studentMap?['parentId'] as num?)?.toInt(),
      avatar: (json['avatar'] as String?) ?? (userMap?['avatar'] as String?),
      isActive: (json['isActive'] as bool?) ?? (userMap?['isActive'] as bool?),
      isAdult:
          ((json['role'] as String?) ?? (userMap?['role'] as String?)) ==
          'ADULT_STUDENT',
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'birthDate': birthDate,
    'address': address,
    'halaqaId': halaqaId,
    'parentId': parentId,
    'role': 'student',
  };
}
