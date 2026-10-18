import 'package:taqwa/core/constants/hadith_books.dart';

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
  // The hadith books the admin assigned, in [kHadithBooks] order. Empty means
  // the recitation sheet offers Quran only.
  final List<String> hadithBooks;
  bool get tracksHadith => hadithBooks.isNotEmpty;

  // Registration-form details (استمارة التسجيل), all optional. [schoolLevel]
  // is a child's school grade or an adult's education level; the parents'
  // jobs belong to the children's form, [occupation], [email] and
  // [isMarried] to the adults'.
  final String? email;
  final String? schoolLevel;
  final String? healthStatus;
  final String? familyStatus;
  final String? fatherJob;
  final String? motherJob;
  final String? occupation;
  final String? externalActivities;
  final bool? isMarried;

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
    this.hadithBooks = const [],
    this.email,
    this.schoolLevel,
    this.healthStatus,
    this.familyStatus,
    this.fatherJob,
    this.motherJob,
    this.occupation,
    this.externalActivities,
    this.isMarried,
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
    String? text(String key) =>
        (json[key] as String?) ?? (studentMap?[key] as String?);

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
      hadithBooks: parseHadithBooks(
        json['hadithBooks'] ?? studentMap?['hadithBooks'],
        tracksHadith:
            (json['tracksHadith'] as bool?) ??
            (studentMap?['tracksHadith'] as bool?) ??
            false,
      ),
      email: (json['email'] as String?) ?? (userMap?['email'] as String?),
      schoolLevel: text('schoolLevel'),
      healthStatus: text('healthStatus'),
      familyStatus: text('familyStatus'),
      fatherJob: text('fatherJob'),
      motherJob: text('motherJob'),
      occupation: text('occupation'),
      externalActivities: text('externalActivities'),
      isMarried:
          (json['isMarried'] as bool?) ?? (studentMap?['isMarried'] as bool?),
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
