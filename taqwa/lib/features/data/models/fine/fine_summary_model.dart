import 'fine_entry_model.dart';

/// The whole answer to "what do I owe" — the running balance plus every entry
/// that produced it.
class FineSummaryModel {
  final int balance;
  final List<FineEntryModel> entries;

  const FineSummaryModel({required this.balance, required this.entries});

  factory FineSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List?) ?? const [];
    return FineSummaryModel(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      entries: rawEntries
          .whereType<Map>()
          .map((e) => FineEntryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
