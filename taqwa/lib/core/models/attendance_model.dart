enum AttendanceStatus { present, absent, late }

class AttendanceModel {
  final int id;
  final int studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;
  final String? studentName;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
    this.studentName,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    AttendanceStatus statusVal = AttendanceStatus.present;
    switch (json['status']) {
      case 'PRESENT':
        statusVal = AttendanceStatus.present;
        break;
      case 'ABSENT':
        statusVal = AttendanceStatus.absent;
        break;
      case 'LATE':
        statusVal = AttendanceStatus.late;
        break;
    }

    String? sName;
    if (json['student'] != null && json['student']['user'] != null) {
      sName = json['student']['user']['fullName'];
    }

    return AttendanceModel(
      id: json['id'],
      studentId: json['studentId'],
      date: DateTime.parse(json['date']),
      status: statusVal,
      notes: json['notes'],
      studentName: sName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'date': date.toIso8601String(),
      'status': status.name.toUpperCase(),
      'notes': notes,
    };
  }
}
