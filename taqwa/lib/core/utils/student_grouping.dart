/// The bucket every student who has not been enrolled in a halaqa falls into.
const String unassignedHalaqaLabel = 'غير مسجلين';

/// One halaqa's slice of a student list. [halaqaId] is null for the bucket of
/// students who belong to no halaqa yet.
class HalaqaGroup {
  const HalaqaGroup({
    required this.halaqaId,
    required this.name,
    required this.students,
  });

  final int? halaqaId;
  final String name;
  final List<Map<String, dynamic>> students;

  bool get isUnassigned => halaqaId == null;
}

/// Splits [students] into one group per halaqa so the roster reads by circle
/// rather than as one flat run of names.
///
/// Groups come back sorted by halaqa name, with the unassigned bucket pinned
/// last; within a group the caller's order is left alone, which keeps the
/// alphabetical order the API already sorts by.
List<HalaqaGroup> groupStudentsByHalaqa(List<Map<String, dynamic>> students) {
  final byHalaqa = <int?, List<Map<String, dynamic>>>{};
  final names = <int?, String>{};

  for (final student in students) {
    final halaqa = student['halaqa'] as Map<String, dynamic>?;
    final name = halaqa?['name']?.toString().trim() ?? '';
    // A halaqa row with no usable name is no more reachable than none at all.
    final id = name.isEmpty ? null : (halaqa?['id'] as num?)?.toInt();

    byHalaqa.putIfAbsent(id, () => []).add(student);
    names[id] = id == null ? unassignedHalaqaLabel : name;
  }

  final ids = byHalaqa.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return names[a]!.compareTo(names[b]!);
    });

  return [
    for (final id in ids)
      HalaqaGroup(halaqaId: id, name: names[id]!, students: byHalaqa[id]!),
  ];
}
