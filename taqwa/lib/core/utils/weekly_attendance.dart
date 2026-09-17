/// One school day in the admin dashboard's weekly attendance chart.
class DayAttendance {
  const DayAttendance({
    required this.label,
    required this.present,
    required this.absent,
  });

  /// The Arabic weekday name, empty when the date could not be read.
  final String label;

  /// Students who turned up — late arrivals included, the same rule the server
  /// applies to attendance everywhere else in the app.
  final int present;

  final int absent;

  /// Everyone marked that day.
  int get marked => present + absent;

  /// Zero marked students means nobody was marked at all, which is not the
  /// same as a day everyone missed. The chart has to draw the two differently
  /// or it accuses the halaqa of an absence that was never recorded.
  bool get hasRecord => marked > 0;
}

const _weekdayNames = {
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
  DateTime.saturday: 'السبت',
};

/// Reads `GET /attendance/week`, which sends one entry per school day of the
/// current week, oldest first.
///
/// The label comes from the date on each entry rather than its position in the
/// list, so a short or shifted week still names its own days correctly.
List<DayAttendance> weeklyAttendanceFrom(List<Map<String, dynamic>> json) {
  return json.map((day) {
    // The column is a bare DATE serialised at UTC midnight; parsing it back to
    // local time can roll the weekday over, so the day is read in UTC.
    final date = DateTime.tryParse(day['date']?.toString() ?? '')?.toUtc();
    return DayAttendance(
      label: date == null ? '' : _weekdayNames[date.weekday] ?? '',
      // A server that sends only a rate leaves both of these at zero, which
      // reads as an unmarked day: a share cannot be turned back into a head
      // count, and inventing one would be worse than drawing nothing.
      present: (day['present'] as num?)?.toInt() ?? 0,
      absent: (day['absent'] as num?)?.toInt() ?? 0,
    );
  }).toList();
}
