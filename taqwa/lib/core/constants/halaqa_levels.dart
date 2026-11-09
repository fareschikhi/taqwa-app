/// A halaqa's category, sent and stored as the halaqa's `level`. The label
/// itself is the stored value, so every screen that prints `level` shows it
/// unchanged. It does not decide whether the halaqa runs on fines: that is the
/// separate adults' switch. Must match `HALAQA_LEVELS` in the backend
/// character for character: the server refuses any other value.
const List<String> kHalaqaLevels = [
  'ابتدائي',
  'متوسط',
  'ثانوي',
  'جامعي (كبار)',
];
