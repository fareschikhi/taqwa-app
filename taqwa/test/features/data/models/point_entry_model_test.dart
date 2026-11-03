import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';

PointEntryModel entry(Map<String, dynamic> over) => PointEntryModel.fromJson({
  'id': 1,
  'source': 'PRESENT',
  'amount': '0.5',
  'reason': null,
  'date': '2026-11-05T00:00:00.000Z',
  'createdAt': '2026-11-05T09:00:00.000Z',
  'createdBy': null,
  ...over,
});

void main() {
  group('label', () {
    test('names every automatic source', () {
      expect(entry({'source': 'MEMORIZATION'}).label, 'حفظ وجمع ومراجعة');
      expect(entry({'source': 'PRESENT'}).label, 'حضور');
      expect(entry({'source': 'ABSENCE'}).label, 'غياب');
      expect(entry({'source': 'MISSED_MEMORIZATION'}).label, 'لم يُسمّع');
    });

    test('uses the reason of a manual entry, or a plain fallback', () {
      expect(entry({'source': 'MANUAL', 'reason': 'سلوك'}).label, 'سلوك');
      expect(entry({'source': 'MANUAL', 'reason': null}).label, 'تعديل يدوي');
    });
  });

  test('reads the amount as an exact number', () {
    expect(entry({'amount': '-1'}).amount, -1);
  });

  test('reads who made a manual entry', () {
    expect(
      entry({
        'source': 'MANUAL',
        'createdBy': {'fullName': 'أحمد'},
      }).createdByName,
      'أحمد',
    );
    expect(entry({}).createdByName, isNull);
  });

  // A bare DATE arrives as UTC midnight; read in a timezone ahead of UTC it
  // must still be the same calendar day.
  test('keeps the calendar day of a date-only value', () {
    final d = entry({}).displayDate;
    expect([d.year, d.month, d.day], [2026, 11, 5]);
  });

  // A date with no 'Z' parses as local midnight; converting it to UTC on a
  // phone ahead of Greenwich (Algeria, UTC+1) would land on the day before.
  test('keeps the calendar day of a date with no timezone', () {
    final d = entry({'date': '2026-11-05'}).displayDate;
    expect([d.year, d.month, d.day], [2026, 11, 5]);
  });

  test('falls back to createdAt for a manual entry with no day', () {
    final d = entry({
      'date': null,
      'createdAt': '2026-11-07T10:00:00.000Z',
    }).displayDate;
    expect([d.year, d.month, d.day], [2026, 11, 7]);
  });

  test('reads who made an entry, by id', () {
    expect(entry({'source': 'MANUAL', 'createdById': 5}).createdById, 5);
    expect(entry({}).createdById, isNull);
  });

  test('only a MANUAL entry is manual', () {
    expect(entry({'source': 'MANUAL'}).isManual, isTrue);
    expect(entry({'source': 'ABSENCE'}).isManual, isFalse);
  });

  test('summary says whose points these are', () {
    final s = PointsSummaryModel.fromJson({
      'userId': 70,
      'total': '1',
      'entries': [],
    });
    expect(s.userId, 70);
    // An older server sends none: the app then simply cannot adjust.
    expect(PointsSummaryModel.fromJson({'total': '1'}).userId, isNull);
  });

  test('summary reads a negative total', () {
    final s = PointsSummaryModel.fromJson({'total': '-0.5', 'entries': []});
    expect(s.total, -0.5);
    expect(s.entries, isEmpty);
  });
}
