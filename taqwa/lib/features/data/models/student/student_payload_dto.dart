class StudentPayloadDto {
  final String fullName;
  final String phone;
  final String birthDate;
  final String address;
  final int? halaqaId;
  final int? parentId;
  final String? avatar;

  /// Initial login password. Optional: the backend stores an empty hash when
  /// it is omitted, which is how students created without one are handled.
  final String? password;

  const StudentPayloadDto({
    required this.fullName,
    required this.phone,
    required this.birthDate,
    required this.address,
    this.halaqaId,
    this.parentId,
    this.avatar,
    this.password,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'birthDate': birthDate,
    'address': address,
    if (halaqaId != null) 'halaqaId': halaqaId,
    if (parentId != null) 'parentId': parentId,
    if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
    if (password != null && password!.isNotEmpty) 'password': password,
    'role': 'STUDENT',
  };
}
