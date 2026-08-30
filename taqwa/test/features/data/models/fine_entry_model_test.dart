import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/fine/fine_entry_model.dart';

void main() {
  // An auto-charge carries the halaqa day it follows from, which can be well
  // before the teacher gets around to entering it — displayDate has to prefer
  // that day over createdAt or a backfilled fine reads as dated today.
  test('displayDate prefers date over createdAt when both are present', () {
    final entry = FineEntryModel.fromJson({
      'id': 1,
      'kind': 'CHARGE',
      'amount': 30,
      'reason': null,
      'source': 'ABSENCE',
      'createdAt': '2026-08-30T10:00:00.000Z',
      'date': '2026-08-20T00:00:00.000Z',
    });

    expect(entry.date, DateTime.parse('2026-08-20T00:00:00.000Z'));
    expect(entry.displayDate, DateTime.parse('2026-08-20T00:00:00.000Z'));
  });

  // A manual entry has no session of its own, so the API sends `date: null`
  // and the day it was typed in is the correct one to show.
  test('displayDate falls back to createdAt when date is null', () {
    final entry = FineEntryModel.fromJson({
      'id': 2,
      'kind': 'REDUCTION',
      'amount': 20,
      'reason': 'دفع',
      'source': 'MANUAL',
      'createdAt': '2026-08-30T10:00:00.000Z',
      'date': null,
    });

    expect(entry.date, isNull);
    expect(entry.displayDate, DateTime.parse('2026-08-30T10:00:00.000Z'));
  });
}
