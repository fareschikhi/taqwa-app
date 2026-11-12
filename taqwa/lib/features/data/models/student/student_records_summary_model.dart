/// The three kinds of history the admin can wipe from a student, each with
/// its own DELETE route (`/students/:id/<path>`). Kept as one enum so the
/// form, the repository and the routes cannot drift apart.
enum StudentRecordKind {
  attendance('attendance'),
  memorization('memorization'),
  points('points');

  const StudentRecordKind(this.path);

  final String path;
}

/// What each reset would erase — `GET /students/:id/records`. Counts are rows;
/// [pointsTotal] is the balance those point rows add up to.
class StudentRecordsSummary {
  const StudentRecordsSummary({
    required this.attendance,
    required this.memorization,
    required this.points,
    required this.pointsTotal,
  });

  final int attendance;
  final int memorization;
  final int points;
  final double pointsTotal;

  factory StudentRecordsSummary.fromJson(Map<String, dynamic> json) =>
      StudentRecordsSummary(
        attendance: (json['attendance'] as num?)?.toInt() ?? 0,
        memorization: (json['memorization'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        pointsTotal: (json['pointsTotal'] as num?)?.toDouble() ?? 0,
      );

  int countOf(StudentRecordKind kind) => switch (kind) {
    StudentRecordKind.attendance => attendance,
    StudentRecordKind.memorization => memorization,
    StudentRecordKind.points => points,
  };
}
