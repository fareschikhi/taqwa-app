import '../enums/memorization_type.dart';

/// What a repeat (إعادة) entry carries after its type, in every history list.
const String kRepeatSuffix = '(اعادة)';

/// The type line of one memorization record, as the history screens print it:
/// «حفظ جديد», «جمع», «مراجعة وضبط», with «(اعادة)» after it on a repeat and
/// «تسميع ·» before it on a برنامج التسميع entry.
///
/// One function for every screen, so the wording and the repeat mark cannot
/// drift apart between the teacher's, the parent's and the student's views.
/// An unknown type falls back to new memorization, matching the column
/// default on the server.
String recordTypeLabel(Map<String, dynamic> record) {
  final type =
      MemorizationTypeX.fromApi(record['memorizationType'] as String?) ??
      MemorizationType.hifz;
  final label = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
  final typed = record['isRepeat'] == true ? '$label $kRepeatSuffix' : label;
  return record['subject'] == 'TASMEE' ? '$kTasmeePrefix · $typed' : typed;
}

/// What a برنامج التسميع entry carries before its type, so it reads apart
/// from a Quran entry in the same list.
const String kTasmeePrefix = 'تسميع';

/// The mistakes the teacher noted on a تسميع (الأخطاء), trimmed, or null when
/// there are none. Only a TASMEE row carries them; any other row reads null
/// whatever its payload holds.
String? recordMistakes(Map<String, dynamic> record) {
  if (record['subject'] != 'TASMEE') return null;
  final text = (record['mistakes'] as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}
