class AttendanceSummaryModel {
  /// Counted over the student's whole enrolment.
  final int present;
  final int absent;

  /// Share of the enrolment the student turned up for, late days included.
  final int rate;

  final int month;

  /// Counted over [month] only. The teacher endpoint sends no breakdown, so
  /// these fall back to zero rather than being required.
  final int monthPresent;
  final int monthAbsent;
  final int monthLate;

  /// Share of the month the student turned up for. A late arrival is still an
  /// arrival, so it counts towards this the same way a punctual day does.
  final int monthRate;

  const AttendanceSummaryModel({
    required this.present,
    required this.absent,
    required this.rate,
    required this.month,
    this.monthPresent = 0,
    this.monthAbsent = 0,
    this.monthLate = 0,
    this.monthRate = 0,
  });

  /// Days the student showed up for this month — on time or late. The rate is
  /// this over this plus [monthAbsent].
  int get monthAttended => monthPresent + monthLate;

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSummaryModel(
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 1,
        monthPresent: (json['monthPresent'] as num?)?.toInt() ?? 0,
        monthAbsent: (json['monthAbsent'] as num?)?.toInt() ?? 0,
        monthLate: (json['monthLate'] as num?)?.toInt() ?? 0,
        monthRate: (json['monthRate'] as num?)?.toInt() ?? 0,
      );
}
