import 'package:taqwa/core/utils/points_format.dart';
import 'point_entry_model.dart';

/// A total and the history behind it, newest first as the server orders it.
class PointsSummaryModel {
  final num total;
  final List<PointEntryModel> entries;

  const PointsSummaryModel({required this.total, required this.entries});

  factory PointsSummaryModel.fromJson(Map<String, dynamic> json) {
    final rows = (json['entries'] as List?) ?? const [];
    return PointsSummaryModel(
      total: parsePoints(json['total']),
      entries: rows
          .whereType<Map>()
          .map((e) => PointEntryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
