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
///
/// With [sortGroups] false the groups keep the order their first student
/// arrived in instead — for a list the server already sent section by
/// section, where re-sorting here could disagree with the database's
/// collation and drop a freshly loaded page into a section above.
List<HalaqaGroup> groupStudentsByHalaqa(
  List<Map<String, dynamic>> students, {
  bool sortGroups = true,
}) {
  final buckets = groupByHalaqa<Map<String, dynamic>>(
    students,
    halaqaIdOf: (s) => ((s['halaqa'] as Map?)?['id'] as num?)?.toInt(),
    halaqaNameOf: (s) => (s['halaqa'] as Map?)?['name']?.toString(),
    sortGroups: sortGroups,
  );
  return [
    for (final b in buckets)
      HalaqaGroup(halaqaId: b.halaqaId, name: b.name, students: b.items),
  ];
}

/// One halaqa's slice of any list whose rows each sit in at most one halaqa,
/// such as a manager's absences. [halaqaId] is null for the unassigned bucket.
class HalaqaBucket<T> {
  const HalaqaBucket({
    required this.halaqaId,
    required this.name,
    required this.items,
  });

  final int? halaqaId;
  final String name;
  final List<T> items;

  bool get isUnassigned => halaqaId == null;
}

/// The rules behind [groupStudentsByHalaqa] for rows of any shape: groups by
/// halaqa name with the unassigned bucket last (or first-arrival order when
/// [sortGroups] is false), and the caller's order kept inside each group.
List<HalaqaBucket<T>> groupByHalaqa<T>(
  List<T> items, {
  required int? Function(T item) halaqaIdOf,
  required String? Function(T item) halaqaNameOf,
  bool sortGroups = true,
}) {
  final byHalaqa = <int?, List<T>>{};
  final names = <int?, String>{};

  for (final item in items) {
    final name = halaqaNameOf(item)?.trim() ?? '';
    // A halaqa row with no usable name is no more reachable than none at all.
    final id = name.isEmpty ? null : halaqaIdOf(item);

    byHalaqa.putIfAbsent(id, () => []).add(item);
    names[id] = id == null ? unassignedHalaqaLabel : name;
  }

  final ids = byHalaqa.keys.toList();
  if (sortGroups) {
    ids.sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return names[a]!.compareTo(names[b]!);
    });
  }

  return [
    for (final id in ids)
      HalaqaBucket(halaqaId: id, name: names[id]!, items: byHalaqa[id]!),
  ];
}
