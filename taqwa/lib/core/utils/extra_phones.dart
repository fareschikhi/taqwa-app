/// How many numbers the + button may add beside the main phone. Matches the
/// backend's MAX_EXTRA_PHONES.
const int kMaxExtraPhones = 4;

/// The API's `extraPhones` JSON array as strings; anything else reads as none.
List<String> parseExtraPhones(Object? raw) => raw is List
    ? raw.whereType<String>().where((p) => p.trim().isNotEmpty).toList()
    : const [];
