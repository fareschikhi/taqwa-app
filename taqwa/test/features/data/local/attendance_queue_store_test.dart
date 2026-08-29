import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/features/data/local/attendance_queue_store.dart';

Map<String, dynamic> record(int studentId, String status) => {
  'studentId': studentId,
  'date': '2026-08-29',
  'status': status,
};

void main() {
  // shared_preferences ships an in-memory implementation, so the round trip
  // is exercised without a device.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('what is written comes back', () async {
    final store = AttendanceQueueStore();

    await store.write(4, [record(1, 'PRESENT'), record(2, 'ABSENT')]);

    expect(await store.read(4), [record(1, 'PRESENT'), record(2, 'ABSENT')]);
  });

  test('an unknown teacher reads as empty rather than throwing', () async {
    final store = AttendanceQueueStore();

    expect(await store.read(99), isEmpty);
  });

  test('clearing empties one teacher', () async {
    final store = AttendanceQueueStore();
    await store.write(4, [record(1, 'PRESENT')]);

    await store.clear(4);

    expect(await store.read(4), isEmpty);
  });

  test('one teacher cannot read another teacher queue', () async {
    final store = AttendanceQueueStore();

    await store.write(4, [record(1, 'PRESENT')]);

    expect(await store.read(5), isEmpty);
  });

  test('unreadable stored data reads as empty rather than throwing', () async {
    // A partial write or an older format must not brick the attendance page.
    SharedPreferences.setMockInitialValues({
      'pending_attendance_4': 'not json',
    });
    final store = AttendanceQueueStore();

    expect(await store.read(4), isEmpty);
  });
}
