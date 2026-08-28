/// One school day in the admin dashboard's weekly attendance chart.
class DayAttendanceRate {
  const DayAttendanceRate({required this.label, required this.rate});

  /// The Arabic weekday name, empty when the date could not be read.
  final String label;

  /// Percentage of marked students who turned up — late arrivals included,
  /// the same rule the server applies to every other rate in the app.
  ///
  /// Null for a day nobody was marked on, which is not the same as a day
  /// everyone missed and must not be drawn as 0%.
  final int? rate;

  bool get hasRecord => rate != null;
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
List<DayAttendanceRate> weeklyRatesFrom(List<Map<String, dynamic>> json) {
  return json.map((day) {
    // The column is a bare DATE serialised at UTC midnight; parsing it back to
    // local time can roll the weekday over, so the day is read in UTC.
    final date = DateTime.tryParse(day['date']?.toString() ?? '')?.toUtc();
    return DayAttendanceRate(
      label: date == null ? '' : _weekdayNames[date.weekday] ?? '',
      rate: (day['rate'] as num?)?.toInt(),
    );
  }).toList();
}
