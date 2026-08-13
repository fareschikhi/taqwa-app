import 'package:taqwa/features/data/models/user_model.dart';

class TeacherModel {
  final int id;
  final int userId;
  final DateTime? hireDate;
  final int studentCount;
  final int halaqaCount;
  final UserModel user;

  TeacherModel({
    required this.id,
    required this.userId,
    required this.user,
    this.hireDate,
    this.studentCount = 0,
    this.halaqaCount = 0,
  });

  String get fullName => user.fullName;
  String? get phone => user.phone;
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

    final int idVal = (teacherMap?['id'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    final int userIdVal = (json['userId'] as num?)?.toInt() ??
        (userMap?['id'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
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
