import '../../features/data/models/student_note_model.dart';

/// One day of the notes timeline: the heading a parent reads ("اليوم",
/// "أمس", or the date) and that day's notes, newest first.
class NoteDay {
  const NoteDay(this.label, this.notes);
  final String label;
  final List<StudentNoteModel> notes;
}

/// When a note was written, on the phone's clock.
///
/// The API sends createdAt in UTC. Reading it without converting would put a
/// note written just after midnight in Algeria on the previous day.
DateTime? noteLocalTime(StudentNoteModel note) =>
    DateTime.tryParse(note.createdAt)?.toLocal();

/// "اليوم" and "أمس" for the two days a parent is most likely checking,
/// dd/MM/yyyy (the app's usual form) for anything older.
String noteDayLabel(DateTime local, DateTime now) {
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  // Calendar difference, not a 24h one: 23:50 yesterday is still "أمس" at
  // 00:10 today.
  final diff = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(day.year, day.month, day.day))
      .inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  return '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';
}

/// 24-hour HH:mm, the way the time is read in Algeria.
String noteTimeLabel(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:'
    '${local.minute.toString().padLeft(2, '0')}';

/// Groups notes under their local day, newest day first and newest note first
/// within a day. A note whose date does not parse is dropped rather than
/// placed on a made-up day.
List<NoteDay> groupNotesByDay(List<StudentNoteModel> notes, DateTime now) {
  final dated = [
    for (final n in notes)
      if (noteLocalTime(n) case final t?) (note: n, at: t),
  ]..sort((a, b) => b.at.compareTo(a.at));

  final days = <NoteDay>[];
  for (final entry in dated) {
    final label = noteDayLabel(entry.at, now);
    if (days.isNotEmpty && days.last.label == label) {
      days.last.notes.add(entry.note);
    } else {
      days.add(NoteDay(label, [entry.note]));
    }
  }
  return days;
}
