class MemorizationProgressSummaryModel {
  final int memorizationPercent;
  final int minorReviewPercent;
  final int majorReviewPercent;

  const MemorizationProgressSummaryModel({
    required this.memorizationPercent,
    required this.minorReviewPercent,
    required this.majorReviewPercent,
  });

  factory MemorizationProgressSummaryModel.fromJson(
      Map<String, dynamic> json) =>
      MemorizationProgressSummaryModel(
        memorizationPercent:
            (json['memorizationPercent'] as num?)?.toInt() ?? 0,
        minorReviewPercent:
            (json['minorReviewPercent'] as num?)?.toInt() ?? 0,
        majorReviewPercent:
            (json['majorReviewPercent'] as num?)?.toInt() ?? 0,
      );
}
