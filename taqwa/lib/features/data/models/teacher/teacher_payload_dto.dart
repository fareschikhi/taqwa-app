class TeacherPayloadDto {
  final String? fullName;
  final String? phone;

  /// More contact numbers beside [phone]; sent even when empty so an edit
  /// that removes them all clears them.
  final List<String> extraPhones;
  final String? password;
  final String? email;
  final String? dateOfBirth;
  final String? address;
  final String? avatar;
  final bool? canPostNews;

  const TeacherPayloadDto({
    this.fullName,
    this.phone,
    this.extraPhones = const [],
    this.password,
    this.email,
    this.dateOfBirth,
    this.address,
    this.avatar,
    this.canPostNews,
  });

  Map<String, dynamic> toJson() => {
    if (fullName != null) 'fullName': fullName,
    if (phone != null) 'phone': phone,
    'extraPhones': extraPhones,
    if (password != null) 'password': password,
    if (email != null) 'email': email,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    if (address != null) 'address': address,
    if (avatar != null) 'avatar': avatar,
    if (canPostNews != null) 'canPostNews': canPostNews,
    'role': 'TEACHER',
  };
}
