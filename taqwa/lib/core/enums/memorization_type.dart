enum MemorizationType { hifz, minorReview, majorReview }

/// Every Quran entry, new or revision, is measured in mushaf pages; a hizb
/// is only a shortcut for entering ten of them.
const String kPageUnitLabel = 'صفحة';
const String kPageAmountLabel = 'عدد الصفحات';
const int kMushafPages = 604;
const int kPagesPerHizb = 10;

extension MemorizationTypeX on MemorizationType {
  String get label => switch (this) {
    MemorizationType.hifz => 'حفظ',
    MemorizationType.minorReview => 'جمع',
    MemorizationType.majorReview => 'مراجعة وضبط',
  };

  String get apiValue => switch (this) {
    MemorizationType.hifz => 'MEMORIZING',
    MemorizationType.minorReview => 'SMALLREVISION',
    MemorizationType.majorReview => 'BIGREVISION',
  };

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
