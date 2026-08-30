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

  /// The halaqa day an auto-charge follows from. Null on a manual entry,
  /// which has no session to be dated by — [displayDate] is what a screen
  /// should render instead of reaching for [createdAt] directly.
  final DateTime? date;

  const FineEntryModel({
    required this.id,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.source,
    required this.createdAt,
    required this.date,
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

  /// The day this entry should be shown as dated. An auto-charge is dated by
  /// the halaqa session it follows from, which can be well before a teacher
  /// gets around to entering it — falling back to [createdAt] would then show
  /// the day the row was written, not the day the fine is about. A manual
  /// entry has no session of its own, so [createdAt] — when it was typed in —
  /// is the correct day for it.
  DateTime get displayDate => date ?? createdAt;

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
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'] as String),
    );
  }
}
