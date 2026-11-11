import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/parent/parent_model.dart';

ParentModel _parse(Map<String, dynamic> user) =>
    ParentModel.fromJson({'id': 1, 'user': {'id': 7, 'fullName': 'Test', ...user}});

void main() {
  test('a parent with neither date never opened the app', () {
    expect(_parse({}).lastActiveAt, isNull);
  });

  // GET /parents nests the user, so the dates arrive under 'user'.
  test('reads both dates from the nested user', () {
    final p = _parse({
      'lastLoginAt': '2026-11-01T08:00:00.000Z',
      'lastSeenAt': '2026-11-10T08:00:00.000Z',
    });
    expect(p.lastLoginAt, DateTime.utc(2026, 11, 1, 8).toLocal());
    expect(p.lastSeenAt, DateTime.utc(2026, 11, 10, 8).toLocal());
  });

  test('last activity is the later of the two', () {
    final seenLater = _parse({
      'lastLoginAt': '2026-11-01T08:00:00.000Z',
      'lastSeenAt': '2026-11-10T08:00:00.000Z',
    });
    expect(seenLater.lastActiveAt, seenLater.lastSeenAt);

    // Backfilled rows can carry a login and no seen date, or the reverse.
    final loginOnly = _parse({'lastLoginAt': '2026-11-01T08:00:00.000Z'});
    expect(loginOnly.lastActiveAt, loginOnly.lastLoginAt);
    final seenOnly = _parse({'lastSeenAt': '2026-11-10T08:00:00.000Z'});
    expect(seenOnly.lastActiveAt, seenOnly.lastSeenAt);
  });

  test('a malformed date reads as never rather than crashing the list', () {
    expect(_parse({'lastSeenAt': 'not a date'}).lastActiveAt, isNull);
  });
}
