class TeacherPayloadDto {
  final String? fullName;
  final String? phone;
  final String? password;
  final String? email;
  final String? dateOfBirth;
  final String? address;
  final String? avatar;

  const TeacherPayloadDto({
    this.fullName,
    this.phone,
    this.password,
    this.email,
    this.dateOfBirth,
    this.address,
    this.avatar,
  });

  Map<String, dynamic> toJson() => {
    if (fullName != null) 'fullName': fullName,
    if (phone != null) 'phone': phone,
    if (password != null) 'password': password,
    if (email != null) 'email': email,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    if (address != null) 'address': address,
    if (avatar != null) 'avatar': avatar,
    'role': 'TEACHER',
  };
}
