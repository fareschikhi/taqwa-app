class StudentPayloadDto {
  final String fullName;
  final String phone;
  final String birthDate;
  final String address;
  final int? halaqaId;
  final int? parentId;
  final String? avatar;

  /// An adult student is his own guardian: he logs in with [password] and has
  /// no parent. A child student is the reverse — a record with no login,
  /// tied to a parent. The backend derives the actual role from [isAdult]
  /// alone (`CreateStudentDto` has no `role` field), so [toJson] must keep
  /// [password] and [parentId] in lockstep with it rather than sending a key
  /// the backend would either ignore or reject.
  final bool isAdult;
  final String? password;
  // Admin opt-in: whether this student's recitation sheet offers a Hadith
  // subject alongside Quran. Always sent, like isAdult, so clearing it back
  // to false on an existing student is possible from the same form.
  final bool tracksHadith;

  const StudentPayloadDto({
    required this.fullName,
    required this.phone,
    required this.birthDate,
    required this.address,
    this.halaqaId,
    this.parentId,
    this.avatar,
    this.isAdult = false,
    this.password,
    this.tracksHadith = false,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'birthDate': birthDate,
    'address': address,
    if (halaqaId != null) 'halaqaId': halaqaId,
    if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
    'isAdult': isAdult,
    'tracksHadith': tracksHadith,
    // A child never logs in, so a password on his record would be exactly
    // the kind of lie the old hardcoded 'role' key used to tell; an adult
    // has no parent by construction, so his record carries none either.
    if (isAdult && password != null && password!.isNotEmpty)
      'password': password,
    if (!isAdult && parentId != null) 'parentId': parentId,
  };
}
