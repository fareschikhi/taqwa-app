class TeacherModel {
  final int? id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? password;
  final String? dateOfBirth;
  final String? address;
  final String? avatar;
  final bool? isActive;

  const TeacherModel({
    this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.password,
    this.dateOfBirth,
    this.address,
    this.avatar,
    this.isActive,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : null;
    final teacherMap = json['teacher'] is Map<String, dynamic>
        ? json['teacher'] as Map<String, dynamic>
        : null;

    return TeacherModel(
      id: (teacherMap?['id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt(),
      fullName:
          (json['fullName'] as String?) ??
          (userMap?['fullName'] as String?) ??
          '',
      phone: (json['phone'] as String?) ?? (userMap?['phone'] as String?),
      email: (json['email'] as String?) ?? (userMap?['email'] as String?),
      dateOfBirth: json['dateOfBirth']?.toString(),
      address: json['address']?.toString(),
      avatar: (json['avatar'] as String?) ??
          (json['image'] as String?) ??
          (userMap?['avatar'] as String?) ??
          (userMap?['image'] as String?),
      isActive: (json['isActive'] as bool?) ?? (userMap?['isActive'] as bool?),
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
        if (address != null) 'address': address,
        'role': 'teacher',
      };
}
