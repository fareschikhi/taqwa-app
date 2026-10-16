import 'halaqa_student_model.dart';

class HalaqaModel {
  final int id;
  final String name;
  final String? level;
  final int teacherId;
  final String? teacherName;
  final int studentCount;

  /// An adults' halaqa charges fines for absence, lateness and a missed
  /// recitation; a child's halaqa never does. Older payloads that predate
  /// this feature omit the four fields below, so they default to "no fines"
  /// rather than leaving the app to guess.
  final bool isAdult;
  final int absenceFee;
  final int lateFee;
  final int missedMemorizationFee;

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
    this.isAdult = false,
    this.absenceFee = 0,
    this.lateFee = 0,
    this.missedMemorizationFee = 0,
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
      isAdult: json['isAdult'] as bool? ?? false,
      absenceFee: (json['absenceFee'] as num?)?.toInt() ?? 0,
      lateFee: (json['lateFee'] as num?)?.toInt() ?? 0,
      missedMemorizationFee:
          (json['missedMemorizationFee'] as num?)?.toInt() ?? 0,
    );
  }

  /// Everything [HalaqaModel.fromJson] reads, in the shape it reads it, so a
  /// copy saved on the phone keeps the fine fields. [toJson] cannot serve
  /// here: it is the create/update payload and carries only four fields.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'level': level,
    'teacherId': teacherId,
    if (teacherName != null)
      'teacher': {
        'user': {'fullName': teacherName},
      },
    '_count': {'students': studentCount},
    'isAdult': isAdult,
    'absenceFee': absenceFee,
    'lateFee': lateFee,
    'missedMemorizationFee': missedMemorizationFee,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'teacherId': teacherId,
    };
  }
}
