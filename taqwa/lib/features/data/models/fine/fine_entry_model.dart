/// One line on a student's fine statement, as `GET /fines/student/:id`
/// returns it.
class FineEntryModel {
  final int id;

  /// `CHARGE` adds to what he owes; `REDUCTION` takes away from it.
  final String kind;

  /// Always positive — [kind] carries the sign, not this field.
  final int amount;

  /// Set only on a manual entry; an automatic charge leaves it null because
  /// [source] already says why it exists.
  final String? reason;

  /// `ABSENCE`, `LATE`, `MISSED_MEMORIZATION`, or `MANUAL`.
  final String source;

  final DateTime createdAt;

  const FineEntryModel({
    required this.id,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.source,
    required this.createdAt,
  });

  /// What the entry says on his statement. Auto-charges carry no reason of
  /// their own — the source is the reason — while a manual entry is whatever
  /// the teacher wrote.
  String get label => switch (source) {
    'ABSENCE' => 'غياب',
    'LATE' => 'تأخر',
    'MISSED_MEMORIZATION' => 'لم يحفظ',
    _ => reason ?? 'تعديل',
  };

  factory FineEntryModel.fromJson(Map<String, dynamic> json) {
    return FineEntryModel(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String? ?? 'CHARGE',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      source: json['source'] as String? ?? 'MANUAL',
      // A malformed date must not cost the whole statement.
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
