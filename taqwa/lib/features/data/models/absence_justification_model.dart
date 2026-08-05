class AbsenceJustificationModel {
  final int? id;
  final int studentId;
  final int attendanceId;
  final int managerId;
  final String reasonType;
  final String? customReason;
  final String? notes;
  final String? createdAt;
  final Map<String, dynamic>? student;
  final Map<String, dynamic>? attendance;
  final Map<String, dynamic>? manager;

  const AbsenceJustificationModel({
    this.id,
    required this.studentId,
    required this.attendanceId,
    required this.managerId,
    required this.reasonType,
    this.customReason,
    this.notes,
    this.createdAt,
    this.student,
    this.attendance,
    this.manager,
  });

  factory AbsenceJustificationModel.fromJson(Map<String, dynamic> json) {
    return AbsenceJustificationModel(
      id: json['id'],
      studentId: json['studentId'],
      attendanceId: json['attendanceId'],
      managerId: json['managerId'],
      reasonType: json['reasonType'] ?? 'OTHER',
      customReason: json['customReason'],
      notes: json['notes'],
      createdAt: json['createdAt'],
      student: json['student'] as Map<String, dynamic>?,
      attendance: json['attendance'] as Map<String, dynamic>?,
      manager: json['manager'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'attendanceId': attendanceId,
        'managerId': managerId,
        'reasonType': reasonType,
        if (customReason != null) 'customReason': customReason,
        if (notes != null) 'notes': notes,
      };

  String get studentName {
    final user = student?['user'] as Map<String, dynamic>?;
    return user?['fullName'] ?? 'غير معروف';
  }

  String get reasonLabel {
    switch (reasonType) {
      case 'ILLNESS':
        return 'مرض';
      case 'OCCASION':
        return 'مناسبة';
      case 'OTHER':
        return customReason ?? 'أخرى';
      default:
        return reasonType;
    }
  }
}
