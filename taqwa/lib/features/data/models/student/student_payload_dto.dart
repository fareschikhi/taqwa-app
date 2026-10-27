class StudentPayloadDto {
  final String fullName;
  final String phone;
  final String? birthDate;
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
  // The hadith books the admin assigned; empty turns hadith off. Null means
  // "not this caller's decision": the backend refuses the key from anyone
  // but an admin, an empty list included, so a manager's form leaves it out
  // entirely.
  final List<String>? hadithBooks;

  /// Registration-form details (استمارة التسجيل) keyed as the backend names
  /// them — `schoolLevel`, `healthStatus`, `email`, `isMarried`… The form
  /// builds this once for create and edit alike, and only with the keys
  /// that belong to the chosen form (child or adult).
  final Map<String, Object> registration;

  const StudentPayloadDto({
    required this.fullName,
    required this.phone,
    this.birthDate,
    required this.address,
    this.halaqaId,
    this.parentId,
    this.avatar,
    this.isAdult = false,
    this.password,
    this.hadithBooks,
    this.registration = const {},
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'birthDate': ?birthDate,
    'address': address,
    if (halaqaId != null) 'halaqaId': halaqaId,
    if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
    'isAdult': isAdult,
    'hadithBooks': ?hadithBooks,
    ...registration,
    // A child never logs in, so a password on his record would be exactly
    // the kind of lie the old hardcoded 'role' key used to tell; an adult
    // has no parent by construction, so his record carries none either.
    if (isAdult && password != null && password!.isNotEmpty)
      'password': password,
    if (!isAdult && parentId != null) 'parentId': parentId,
  };
}
