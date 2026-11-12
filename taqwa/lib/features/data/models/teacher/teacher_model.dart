import 'package:taqwa/features/data/models/user_model.dart';

class TeacherModel {
  final int id;
  final int userId;
  final DateTime? hireDate;
  final int studentCount;
  final int halaqaCount;

  /// Granted by the admin: may post news to their own halaqas.
  final bool canPostNews;

  /// معلم مشرف, switched on by the admin. He supervises the level of each
  /// halaqa he runs ([halaqaLevels]); the level itself is never picked.
  final bool isSupervisor;

  /// The distinct levels of the halaqas he runs. Empty means the supervisor
  /// switch cannot be turned on: there is no level for him to supervise.
  final List<String> halaqaLevels;
  final UserModel user;

  TeacherModel({
    required this.id,
    required this.userId,
    required this.user,
    this.hireDate,
    this.studentCount = 0,
    this.halaqaCount = 0,
    this.canPostNews = false,
    this.isSupervisor = false,
    this.halaqaLevels = const [],
  });

  String get fullName => user.fullName;
  String? get phone => user.phone;
  List<String> get extraPhones => user.extraPhones;
  String? get email => user.email;
  String? get avatar => user.avatar;
  bool get isActive => user.isActive;

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : null;
    final teacherMap = json['teacher'] is Map<String, dynamic>
        ? json['teacher'] as Map<String, dynamic>
        : null;

    final int idVal =
        (teacherMap?['id'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    // The row's own id is the account id only on a user-shaped row (teacher
    // nested under "teacher"); on a teacher row it is the teacher id, and
    // using it would point points adjustments at another account.
    final int userIdVal =
        (json['userId'] as num?)?.toInt() ??
        (userMap?['id'] as num?)?.toInt() ??
        (teacherMap != null ? (json['id'] as num?)?.toInt() : null) ??
        0;

    final DateTime? hDate = json['hireDate'] != null
        ? DateTime.tryParse(json['hireDate'].toString())
        : (teacherMap?['hireDate'] != null
              ? DateTime.tryParse(teacherMap!['hireDate'].toString())
              : null);

    final UserModel userObj = userMap != null
        ? UserModel.fromJson(userMap)
        : UserModel.fromJson(json);

    return TeacherModel(
      id: idVal,
      userId: userIdVal,
      hireDate: hDate,
      user: userObj,
      studentCount: (json['_count']?['students'] as num?)?.toInt() ?? 0,
      halaqaCount: (json['_count']?['halaqas'] as num?)?.toInt() ?? 0,
      canPostNews: (json['canPostNews'] as bool?) ?? false,
      isSupervisor: (json['isSupervisor'] as bool?) ?? false,
      halaqaLevels:
          (json['halaqaLevels'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': user.fullName,
    if (user.phone != null) 'phone': user.phone,
    if (user.email != null) 'email': user.email,
    if (user.avatar != null) 'avatar': user.avatar,
    'role': 'TEACHER',
  };
}
