/// The teacher's free-text overall rating from a `GET /students/:id/profile`
/// body, or null when none is set. An empty string is how a rating is
/// cleared, so it reads as unset too.
String? ratingOf(Map<String, dynamic>? profile) {
  final raw = (profile?['currentRating'] as String?)?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}
