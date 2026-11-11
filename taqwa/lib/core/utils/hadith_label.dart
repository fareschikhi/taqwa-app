import '../enums/memorization_type.dart' show kPageUnitLabel;
import 'ayah_range.dart';
import 'memorization_amount.dart';

/// The unit word for hadith entries, shared across all display sites.
const String kHadithUnitLabel = 'حديث';

/// Display text for a hadith reference: ensures the three display sites
/// (memorization summary, student details, last session) all show the same
/// fallback label when reference is missing or empty.
String hadithLabelOrFallback(String? reference) =>
    (reference != null && reference.trim().isNotEmpty)
    ? reference
    : kHadithUnitLabel;

/// Whether a memorization row's amount is in pages. A Quran row is, unless
/// the teacher recorded an ayah range; a hadith row is only when the teacher
/// chose pages. A hadith row with no `unit` predates the choice and counted
/// single hadiths.
bool countsInPages({required bool isHadith, Object? unit}) =>
    isHadith ? unit == 'PAGE' : unit != 'AYAH';

/// The unit word for one memorization row as the API sends it: `صفحة`,
/// `حديث` or `آية`. Every screen that prints an amount uses this, so a hadith
/// entry counted in pages never reads "2.5 حديث".
String amountUnitLabel(Map<String, dynamic> record) {
  if (record['subject'] != 'HADITH' && record['unit'] == 'AYAH') {
    return kAyahUnitLabel;
  }
  return countsInPages(
        isHadith: record['subject'] == 'HADITH',
        unit: record['unit'],
      )
      ? kPageUnitLabel
      : kHadithUnitLabel;
}

/// How much one entry covered, as people read it: «2.5 صفحة», «4 حديث», or
/// for an ayah entry the range itself, «الآيات 1–20» — the range says more
/// than its count. An ayah row missing its range still reads «20 آية».
String entryAmountText({
  required num? amount,
  required bool isHadith,
  Object? unit,
  int? ayahFrom,
  int? ayahTo,
}) {
  if (!isHadith && unit == 'AYAH') {
    if (ayahFrom != null && ayahTo != null) {
      return ayahRangeLabel(ayahFrom, ayahTo);
    }
    return '${formatAmount(amount)} $kAyahUnitLabel';
  }
  final word = countsInPages(isHadith: isHadith, unit: unit)
      ? kPageUnitLabel
      : kHadithUnitLabel;
  return '${formatAmount(amount)} $word';
}

/// [entryAmountText] for a memorization row straight off the API.
String recordAmountText(Map<String, dynamic> record) => entryAmountText(
  amount: record['amountDone'] as num?,
  isHadith: record['subject'] == 'HADITH',
  unit: record['unit'],
  ayahFrom: (record['ayahFrom'] as num?)?.toInt(),
  ayahTo: (record['ayahTo'] as num?)?.toInt(),
);
