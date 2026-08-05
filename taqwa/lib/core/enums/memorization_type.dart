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
}
