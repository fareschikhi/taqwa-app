import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/constants/hadith_books.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/features/data/local/attendance_roster_cache.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';

const today = '2026-10-16';

final student = TeacherStudentModel(
  id: 7,
  fullName: 'أحمد',
  avatar: '/uploads/a.png',
  isActive: true,
  teacherId: 4,
  halaqaId: 2,
  hadithBooks: [kHadithBooks[1]],
);

final halaqa = HalaqaModel(
  id: 2,
  name: 'الفجر',
  teacherId: 4,
  isAdult: true,
  absenceFee: 100,
  lateFee: 50,
  missedMemorizationFee: 30,
);

final attendanceRow = {
  'studentId': 7,
  'status': 'ABSENT',
  'missedMemorization': false,
};

final memorizationRow = {'studentId': 7, 'surah': 'البقرة'};

AttendanceRosterCache cacheAt(DateTime now) =>
    AttendanceRosterCache(now: () => now);

Future<void> writeSample(AttendanceRosterCache cache, {String date = today}) =>
    cache.write(
      4,
      date: date,
      students: [student],
      halaqas: [halaqa],
      attendance: [attendanceRow],
      memorization: [memorizationRow],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('what is written comes back with the time it was saved', () async {
    final savedAt = DateTime(2026, 10, 16, 8, 30);
    await writeSample(cacheAt(savedAt));

    final roster = await cacheAt(
      DateTime(2026, 10, 16, 9),
    ).read(4, date: today);

    expect(roster, isNotNull);
    expect(roster!.savedAt, savedAt);
    expect(roster.attendance, [attendanceRow]);
    expect(roster.memorization, [memorizationRow]);

    final s = roster.students.single;
    expect(s.id, 7);
    expect(s.fullName, 'أحمد');
    expect(s.avatar, '/uploads/a.png');
    expect(s.isActive, isTrue);
    expect(s.teacherId, 4);
    expect(s.halaqaId, 2);
    expect(s.hadithBooks, [kHadithBooks[1]]);

    // The fine fields are what decide whether the toggle renders and what it
    // charges, so losing them offline would silently turn adults into kids.
    final h = roster.halaqas.single;
    expect(h.id, 2);
    expect(h.name, 'الفجر');
    expect(h.isAdult, isTrue);
    expect(h.absenceFee, 100);
    expect(h.lateFee, 50);
    expect(h.missedMemorizationFee, 30);
  });

  test("another day's marks are not served as today's", () async {
    await writeSample(cacheAt(DateTime(2026, 10, 15, 8)), date: '2026-10-15');

    final roster = await cacheAt(
      DateTime(2026, 10, 16, 8),
    ).read(4, date: today);

    // The roster itself is still worth showing; only the day's rows expire.
    expect(roster!.students.single.id, 7);
    expect(roster.attendance, isEmpty);
    expect(roster.memorization, isEmpty);
  });

  test('a teacher with nothing cached reads as null', () async {
    expect(await cacheAt(DateTime(2026)).read(99, date: today), isNull);
  });

  test('one teacher cannot read another teacher roster', () async {
    await writeSample(cacheAt(DateTime(2026, 10, 16)));

    expect(await cacheAt(DateTime(2026, 10, 16)).read(5, date: today), isNull);
  });

  test('unreadable stored data reads as null rather than throwing', () async {
    SharedPreferences.setMockInitialValues({'attendance_roster_4': '{oops'});

    expect(await cacheAt(DateTime(2026)).read(4, date: today), isNull);
  });
}
