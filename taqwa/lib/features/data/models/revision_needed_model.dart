class RevisionNeededModel {
  final int id;
  final String name;
  final String? avatar;
  final String? halaqa;
  final String? lastMemorizationDate;
  final int daysWithoutMemorization;

  const RevisionNeededModel({
    required this.id,
    required this.name,
    this.avatar,
    this.halaqa,
    this.lastMemorizationDate,
    required this.daysWithoutMemorization,
  });

  factory RevisionNeededModel.fromJson(Map<String, dynamic> json) =>
      RevisionNeededModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        halaqa: json['halaqa'] as String?,
        lastMemorizationDate: json['lastMemorizationDate'] as String?,
        daysWithoutMemorization:
            (json['daysWithoutMemorization'] as num?)?.toInt() ?? 0,
      );
}
