class StudentModel {
  final int? id;
  final String fullName;
  final String? phone;
  final String birthDate;
  final String address;
  final int? halaqaId;
  final int? parentId;
  final String? avatar;
  final bool? isActive;

  const StudentModel({
    this.id,
    required this.fullName,
    this.phone,
    this.birthDate = '',
    this.address = '',
    this.halaqaId,
    this.parentId,
    this.avatar,
    this.isActive,
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
