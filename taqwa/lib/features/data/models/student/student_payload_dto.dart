class StudentPayloadDto {
  final String fullName;
  final String phone;
  final String birthDate;
  final String address;
  final int? halaqaId;
  final int? parentId;
  final String? avatar;

  const StudentPayloadDto({
    required this.fullName,
    required this.phone,
    required this.birthDate,
    required this.address,
    this.halaqaId,
    this.parentId,
    this.avatar,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'birthDate': birthDate,
    'address': address,
    if (halaqaId != null) 'halaqaId': halaqaId,
    if (parentId != null) 'parentId': parentId,
    if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
    // No password: a student is a record, not an account, and the backend
    // rejects a STUDENT login outright.
    'role': 'STUDENT',
  };
}
