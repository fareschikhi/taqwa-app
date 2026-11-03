import 'package:taqwa/core/utils/points_format.dart';

/// One line of a points history, as `GET /points/...` returns it.
class PointEntryModel {
  final int id;

  /// `MEMORIZATION`, `PRESENT`, `ABSENCE`, `MISSED_MEMORIZATION` or `MANUAL`.
  final String source;

  /// Signed: the sign is the direction.
  final num amount;

  /// Only a manual entry can carry one, and even then it is optional.
  final String? reason;

  final DateTime createdAt;

  /// The halaqa day an automatic entry follows from; null on a manual one.
  final DateTime? date;

  /// Who made a manual adjustment. Null on automatic entries.
  final String? createdByName;

  /// The account behind [createdByName]: undo is offered on one's own
  /// manual entries only. Null on automatic entries.
  final int? createdById;

  const PointEntryModel({
    required this.id,
    required this.source,
    required this.amount,
    required this.reason,
    required this.createdAt,
    required this.date,
    required this.createdByName,
    this.createdById,
  });

  /// Typed by a person, as opposed to following from attendance or a
  /// recitation. Only these can be undone.
  bool get isManual => source == 'MANUAL';

  String get label => switch (source) {
    'MEMORIZATION' => 'حفظ وجمع ومراجعة',
    'PRESENT' => 'حضور',
    'ABSENCE' => 'غياب',
    'MISSED_MEMORIZATION' => 'لم يُسمّع',
    _ => (reason == null || reason!.trim().isEmpty) ? 'تعديل يدوي' : reason!,
  };

  /// The calendar day to show. An automatic entry is dated by its halaqa day,
  /// which is a calendar day, not a moment: its year/month/day are taken as
  /// written ("…T00:00:00Z" or a bare "2026-11-05"), never shifted into a
  /// time zone. A manual entry is a real moment, shown on the phone's own
  /// calendar.
  DateTime get displayDate {
    final day = date;
    if (day != null) return DateTime(day.year, day.month, day.day);
    return createdAt.toLocal();
  }

  factory PointEntryModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    return PointEntryModel(
      id: (json['id'] as num).toInt(),
      source: json['source'] as String? ?? 'MANUAL',
      amount: parsePoints(json['amount']),
      reason: json['reason'] as String?,
      // A malformed date must not cost the whole history.
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'] as String),
      createdByName: createdBy is Map ? createdBy['fullName'] as String? : null,
      createdById: (json['createdById'] as num?)?.toInt(),
    );
  }
}

/// Whether this viewer may undo [entry]: only manual entries; the admin any of
/// them, staff only their own. The server checks the same and more (staff
/// must still be able to adjust that student); this only decides whether to
/// offer the button.
bool canUndoPointEntry(
  PointEntryModel entry, {
  required int? viewerId,
  required bool viewerIsAdmin,
}) {
  if (!entry.isManual) return false;
  if (viewerIsAdmin) return true;
  return viewerId != null && entry.createdById == viewerId;
}
