import '../enums/memorization_type.dart' show kPageUnitLabel;
import 'ayah_range.dart' show kAyahUnitLabel;
import 'hadith_label.dart' show kHadithUnitLabel;
import 'memorization_amount.dart';

/// One unit's running total of new memorization, e.g. 40 آية.
typedef UnitTotal = ({num value, String unit});

/// The units a subject's totals are shown in, in reading order. A unit with
/// nothing in it is left out, but the first unit always stays so a student
/// with no entries still reads «0 صفحة» rather than nothing.
List<UnitTotal> visibleTotals(List<UnitTotal> totals) {
  final shown = [
    for (final (i, total) in totals.indexed)
      if (total.value > 0 || i == 0) total,
  ];
  // The first unit was only kept as a placeholder; once another unit has
  // something in it, a «0 صفحة» beside «40 آية» is noise.
  if (shown.length > 1 && shown.first.value <= 0) shown.removeAt(0);
  return shown;
}

/// Quran totals: pages and ayahs are different units, never added together.
List<UnitTotal> quranTotals({num? pages, num? ayahs}) => visibleTotals([
  (value: pages ?? 0, unit: kPageUnitLabel),
  (value: ayahs ?? 0, unit: kAyahUnitLabel),
]);

/// Hadith totals: single hadiths and hadith pages, side by side.
List<UnitTotal> hadithTotals({num? hadiths, num? pages}) => visibleTotals([
  (value: hadiths ?? 0, unit: kHadithUnitLabel),
  (value: pages ?? 0, unit: kPageUnitLabel),
]);

/// «12 صفحة · 40 آية». [separator] is a line break where the text sits in a
/// narrow figure, so each unit gets its own line.
String totalsText(List<UnitTotal> totals, {String separator = ' · '}) =>
    totals.map((t) => '${formatAmount(t.value)} ${t.unit}').join(separator);
