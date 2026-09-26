import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/note_timeline.dart';
import 'package:taqwa/features/data/models/student_note_model.dart';

/// A note as the API returns it: createdAt is UTC. Built from a local time so
/// the tests hold whatever timezone the machine running them is in.
StudentNoteModel note(int id, DateTime local) => StudentNoteModel(
  id: id,
  studentId: 1,
  teacherId: 1,
  note: 'ملاحظة $id',
  createdAt: local.toUtc().toIso8601String(),
);

void main() {
  final now = DateTime(2026, 9, 25, 10, 0);

  group('noteDayLabel', () {
    test('names today and yesterday', () {
      expect(noteDayLabel(DateTime(2026, 9, 25, 8), now), 'اليوم');
      expect(noteDayLabel(DateTime(2026, 9, 24, 23, 50), now), 'أمس');
    });

    test('goes by the calendar, not by 24 hours', () {
      final justAfterMidnight = DateTime(2026, 9, 25, 0, 10);
      expect(noteDayLabel(DateTime(2026, 9, 24, 23, 50), justAfterMidnight), 'أمس');
    });

    test('gives older days as dd/MM/yyyy', () {
      expect(noteDayLabel(DateTime(2026, 9, 3), now), '03/09/2026');
    });
  });

  test('noteTimeLabel is 24-hour HH:mm', () {
    expect(noteTimeLabel(DateTime(2026, 9, 25, 7, 5)), '07:05');
    expect(noteTimeLabel(DateTime(2026, 9, 25, 16, 30)), '16:30');
  });

  test('noteLocalTime reads the UTC timestamp on the local clock', () {
    final local = DateTime(2026, 9, 25, 0, 30);
    expect(noteLocalTime(note(1, local)), local);
  });

  group('groupNotesByDay', () {
    test('puts newest day first and newest note first within it', () {
      final days = groupNotesByDay([
        note(1, DateTime(2026, 9, 24, 9)),
        note(2, DateTime(2026, 9, 25, 8)),
        note(3, DateTime(2026, 9, 25, 9)),
        note(4, DateTime(2026, 9, 20, 9)),
      ], now);

      expect(days.map((d) => d.label), ['اليوم', 'أمس', '20/09/2026']);
      expect(days[0].notes.map((n) => n.id), [3, 2]);
    });

    test('drops a note whose date does not parse', () {
      final broken = StudentNoteModel(
        id: 9,
        studentId: 1,
        teacherId: 1,
        note: 'x',
        createdAt: '',
      );
      final days = groupNotesByDay([broken, note(1, now)], now);
      expect(days.single.notes.single.id, 1);
    });

    test('is empty for no notes', () {
      expect(groupNotesByDay([], now), isEmpty);
    });
  });
}
