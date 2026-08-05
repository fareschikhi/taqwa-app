import 'student/student_model.dart';

class HalaqaModel {
  final int id;
  final String name;
  final String? description;
  final String? level;
  final int teacherId;
  final String? teacherName;
  final int studentCount;
  final List<StudentModel> students;

  HalaqaModel({
    required this.id,
    required this.name,
    this.description,
    this.level,
    required this.teacherId,
    this.teacherName,
    this.studentCount = 0,
    this.students = const [],
  });

  factory HalaqaModel.fromJson(Map<String, dynamic> json) {
    String? tName;
    if (json['teacher'] != null && json['teacher']['user'] != null) {
      tName = json['teacher']['user']['fullName'];
    }

    var studentsList = <StudentModel>[];
    if (json['students'] != null) {
      for (var item in json['students']) {
        if (item['student'] != null) {
          studentsList.add(StudentModel.fromJson(item['student']));
        }
      }
    }

    int sCount = json['_count'] != null
        ? json['_count']['students'] ?? 0
        : studentsList.length;

    return HalaqaModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      level: json['level'],
      teacherId: json['teacherId'],
      teacherName: tName,
      studentCount: sCount,
      students: studentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level,
      'teacherId': teacherId,
    };
  }
}
