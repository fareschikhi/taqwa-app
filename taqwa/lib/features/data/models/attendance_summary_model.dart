/// Attendance figures for one subject: a single student from
/// `GET /attendance/student/:id/summary`, or a teacher's whole halaqa from
/// `GET /teachers/:id/attendance-summary`.
///
/// The two endpoints scope [present] and [absent] differently, and nothing in
/// the payload says which one you are holding:
///
/// * the student endpoint counts the **whole enrolment**, and keeps [late]
///   apart from [present] so a punctual day stays distinguishable from a late
///   one — use [attended] to put them back together;
/// * the teacher endpoint counts the **current month**, and has already folded
///   late arrivals into [present]. It sends no `month*` breakdown, so those
///   fields read as zero there.
///
/// Prefer the `month`-prefixed fields wherever the screen names its window to
/// the user, since those mean the same thing from both endpoints.
///
/// The server also sends `rate` and `monthRate` percentages. They are dropped
/// deliberately: the app reports attendance as a number of days, so a share
/// has nowhere to be shown and keeping the field would only invite one back.
class AttendanceSummaryModel {
  const AttendanceSummaryModel({
    required this.present,
    required this.absent,
    required this.month,
    this.late = 0,
    this.monthPresent = 0,
    this.monthAbsent = 0,
    this.monthLate = 0,
    this.currentStreak = 0,
  });

  final int present;
  final int absent;

  /// Late arrivals, counted apart from [present] by the student endpoint and
  /// already inside it on the teacher one, where this stays zero.
  final int late;

  /// The calendar month the `month*` figures cover, 1-12.
  final int month;

  /// Counted over [month] only. The teacher endpoint sends no breakdown, so
  /// these fall back to zero rather than being required.
  final int monthPresent;
  final int monthAbsent;
  final int monthLate;

  /// Days attended in a row, counting back from the most recent record. A late
  /// day continues it, for the same reason it counts as attendance. These are
  /// attendance records rather than calendar days: a halaqa carries no
  /// schedule, so a day nobody was marked on is not a broken streak.
  final int currentStreak;

  /// Days the student showed up for this month — on time or late.
  int get monthAttended => monthPresent + monthLate;

  /// Days attended over the whole enrolment. On the teacher endpoint [late] is
  /// zero because it is already inside [present], so this stays correct there.
  int get attended => present + late;

  /// Days marked this month, present and absent alike. Zero means nothing has
  /// been recorded yet, which is not the same as a month fully missed.
  int get monthMarked => monthAttended + monthAbsent;

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSummaryModel(
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 1,
        monthPresent: (json['monthPresent'] as num?)?.toInt() ?? 0,
        monthAbsent: (json['monthAbsent'] as num?)?.toInt() ?? 0,
        monthLate: (json['monthLate'] as num?)?.toInt() ?? 0,
        // Older servers do not send it; zero reads as 'no streak yet'.
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      );
}
