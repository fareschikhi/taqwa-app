/// Display text for a hadith reference: ensures the three display sites
/// (memorization summary, student details, last session) all show the same
/// fallback label when reference is missing or empty.
String hadithLabelOrFallback(String? reference) =>
    (reference != null && reference.trim().isNotEmpty) ? reference : 'حديث';
