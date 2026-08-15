enum MemorizationType { hifz, minorReview, majorReview }

extension MemorizationTypeX on MemorizationType {
  String get label => switch (this) {
    MemorizationType.hifz => 'حفظ',
    MemorizationType.minorReview => 'مراجعة صغرى',
    MemorizationType.majorReview => 'مراجعة كبرى',
  };

  String get apiValue => switch (this) {
    MemorizationType.hifz => 'MEMORIZING',
    MemorizationType.minorReview => 'SMALLREVISION',
    MemorizationType.majorReview => 'BIGREVISION',
  };

  /// New memorization is measured in pages; revision is measured in hizbs.
  /// Every unit-dependent label and bound below hangs off this one split, so
  /// nothing else in the app should re-derive it from the type.
  bool get isCountedInPages => this == MemorizationType.hifz;

  String get unitLabel => isCountedInPages ? 'صفحة' : 'حزب';

  String get amountLabel => isCountedInPages ? 'عدد الصفحات' : 'عدد الأحزاب';

  int get maxAmount => isCountedInPages ? 604 : 60;

  /// Parses the enum sent by the API. Read screens pull the raw string off
  /// untyped JSON, so an absent or unexpected value yields null rather than
  /// throwing at them.
  static MemorizationType? fromApi(String? value) => switch (value) {
    'MEMORIZING' => MemorizationType.hifz,
    'SMALLREVISION' => MemorizationType.minorReview,
    'BIGREVISION' => MemorizationType.majorReview,
    _ => null,
  };
}
