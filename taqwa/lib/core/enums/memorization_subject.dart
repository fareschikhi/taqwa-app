/// What kind of recitation a memorization row records. QURAN is the default
/// for every existing row; HADITH only exists for a student the admin has
/// opted into hadith tracking, and TASMEE (برنامج التسميع) for one opted into
/// that program — a Quran recitation with the teacher's notes on mistakes.
enum MemorizationSubject { quran, hadith, tasmee }

extension MemorizationSubjectX on MemorizationSubject {
  String get label => switch (this) {
    MemorizationSubject.quran => 'القرآن',
    MemorizationSubject.hadith => 'الحديث',
    MemorizationSubject.tasmee => 'تسميع',
  };

  String get apiValue => switch (this) {
    MemorizationSubject.quran => 'QURAN',
    MemorizationSubject.hadith => 'HADITH',
    MemorizationSubject.tasmee => 'TASMEE',
  };

  /// Parses the enum sent by the API. Read screens pull the raw string off
  /// untyped JSON, so an absent or unexpected value yields null rather than
  /// throwing at them; callers default the result to [MemorizationSubject.quran].
  static MemorizationSubject? fromApi(String? value) => switch (value) {
    'QURAN' => MemorizationSubject.quran,
    'HADITH' => MemorizationSubject.hadith,
    'TASMEE' => MemorizationSubject.tasmee,
    _ => null,
  };
}
