/// How a teacher's students are spread across the three memorization stages.
///
/// These are head counts, not shares: the dashboard reports how many students
/// sit at each stage rather than what fraction of the halaqa they make up, so
/// a teacher with four students is not told "25%" when he means one person.
class MemorizationProgressSummaryModel {
  const MemorizationProgressSummaryModel({
    required this.memorizingCount,
    required this.minorReviewCount,
    required this.majorReviewCount,
    required this.studentsCount,
  });

  /// Students with no revision records yet.
  final int memorizingCount;

  /// Students who have started revising.
  final int minorReviewCount;

  /// Students who have finished memorizing and are on major revision.
  final int majorReviewCount;

  /// Everyone the three counts are drawn from, so a stage can be shown against
  /// the size of the halaqa rather than as a bare number with nothing to weigh
  /// it against.
  final int studentsCount;

  factory MemorizationProgressSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) => MemorizationProgressSummaryModel(
    memorizingCount: (json['memorizingCount'] as num?)?.toInt() ?? 0,
    minorReviewCount: (json['minorReviewCount'] as num?)?.toInt() ?? 0,
    majorReviewCount: (json['majorReviewCount'] as num?)?.toInt() ?? 0,
    studentsCount: (json['studentsCount'] as num?)?.toInt() ?? 0,
  );
}
