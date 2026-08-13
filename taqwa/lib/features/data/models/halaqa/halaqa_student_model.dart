import 'package:taqwa/features/data/models/user_model.dart';

class HalaqaStudentModel {
  final int id;
  final int userId;
  final DateTime? birthDate;
  final int? teacherId;
  final UserModel user;
  final String? teacherName;
  final int? attendanceRate;
  final int? averageMemorizationScore;
  final int? averageRevisionScore;

  HalaqaStudentModel({
    required this.id,
    required this.userId,
    this.birthDate,
    this.teacherId,
    required this.user,
    this.teacherName,
    this.attendanceRate,
    this.averageMemorizationScore,
    this.averageRevisionScore,
  });

  factory HalaqaStudentModel.fromJson(Map<String, dynamic> json) {
    String? tName;
    if (json['teacher'] != null && json['teacher']['user'] != null) {
      tName = json['teacher']['user']['fullName'];
    }

    return HalaqaStudentModel(
      id: (json['id'] as num?)?.toInt() ?? (json['student']?['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? (json['user']?['id'] as num?)?.toInt() ?? 0,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'])
          : null,
      teacherId: json['teacherId'],
      user: UserModel.fromJson(json['user'] ?? json),
      teacherName: tName,
      attendanceRate: json['attendanceRate'],
      averageMemorizationScore: json['averageMemorizationScore'],
      averageRevisionScore: json['averageRevisionScore'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'birthDate': birthDate?.toIso8601String(),
      'teacherId': teacherId,
      'user': user.toJson(),
      'attendanceRate': attendanceRate,
    };
  }
}
