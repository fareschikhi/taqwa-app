import '../enums/memorization_type.dart' show kPageUnitLabel;

/// The unit word for hadith entries, shared across all display sites.
const String kHadithUnitLabel = 'حديث';

/// Display text for a hadith reference: ensures the three display sites
/// (memorization summary, student details, last session) all show the same
/// fallback label when reference is missing or empty.
String hadithLabelOrFallback(String? reference) =>
    (reference != null && reference.trim().isNotEmpty)
    ? reference
    : kHadithUnitLabel;

/// Whether a memorization row's amount is in pages. Quran always is; a hadith
/// row is only when the teacher chose pages. A hadith row with no `unit`
/// predates the choice and counted single hadiths.
bool countsInPages({required bool isHadith, Object? unit}) =>
    !isHadith || unit == 'PAGE';

/// The unit word for one memorization row as the API sends it: `صفحة` or
/// `حديث`. Every screen that prints an amount uses this, so a hadith entry
/// counted in pages never reads "2.5 حديث".
String amountUnitLabel(Map<String, dynamic> record) =>
    countsInPages(isHadith: record['subject'] == 'HADITH', unit: record['unit'])
    ? kPageUnitLabel
    : kHadithUnitLabel;
