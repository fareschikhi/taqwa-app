/// The balance as a student should read it.
///
/// The server already clamps, but the app does too rather than trusting a
/// number it renders in the largest type on the screen: a negative fine is
/// never a thing anyone owes.
int displayedBalance(int raw) => raw < 0 ? 0 : raw;

/// An amount with its currency, for display only.
String formatFine(int amount) => '$amount دج';
