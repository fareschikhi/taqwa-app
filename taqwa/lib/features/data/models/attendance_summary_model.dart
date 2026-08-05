class AttendanceSummaryModel {
  final int present;
  final int absent;
  final int rate;
  final int month;

  const AttendanceSummaryModel({
    required this.present,
    required this.absent,
    required this.rate,
    required this.month,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSummaryModel(
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 1,
      );
}
