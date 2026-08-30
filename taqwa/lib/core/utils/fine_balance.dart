/// The balance as a student should read it.
///
/// The server already clamps, but the app does too rather than trusting a
/// number it renders in the largest type on the screen: a negative fine is
/// never a thing anyone owes.
int displayedBalance(int raw) => raw < 0 ? 0 : raw;

/// An amount with its currency, for display only.
String formatFine(int amount) => '$amount دج';

/// Why this adjustment cannot be submitted, or null when it can.
///
/// The server enforces the same floor and is the authority; this exists so the
/// teacher is told before the round trip rather than after it.
String? fineAdjustError({
  required int amount,
  required String kind,
  required int balance,
}) {
  if (amount <= 0) return 'أدخل مبلغاً أكبر من صفر';
  if (kind == 'REDUCTION' && amount > balance) {
    return 'قيمة الخصم أكبر من الرصيد المستحق';
  }
  return null;
}
