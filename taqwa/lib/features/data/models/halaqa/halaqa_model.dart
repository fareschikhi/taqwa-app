import 'halaqa_student_model.dart';

class HalaqaModel {
  final int id;
  final String name;
  final String? level;
  final int teacherId;
  final String? teacherName;
  final int studentCount;

  /// Always empty as of today's API. `GET /halaqas` (`findAll`) selects only
  /// the teacher and `_count.students`, so no student rows arrive at all; and
  /// `Halaqa.students` is a plain `Student[]` relation, so the rows that
  /// `GET /halaqas/:id` (`findOne`) does return are bare students, not the
  /// `{ student: {...} }` join rows the parser below reads. Use
  /// [studentCount] for the size of a roster; there is currently no endpoint
  /// that fills this list.
  final List<HalaqaStudentModel> students;

  HalaqaModel({
    required this.id,
    required this.name,
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

    var studentsList = <HalaqaStudentModel>[];
    if (json['students'] != null) {
      for (var item in json['students']) {
        if (item['student'] != null) {
          studentsList.add(HalaqaStudentModel.fromJson(item['student']));
        }
      }
    }

    int sCount = json['_count'] != null
        ? json['_count']['students'] ?? 0
        : studentsList.length;

    return HalaqaModel(
      id: json['id'],
      name: json['name'],
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
      'level': level,
      'teacherId': teacherId,
    };
  }
}
