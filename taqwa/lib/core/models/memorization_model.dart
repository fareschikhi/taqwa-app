class MemorizationModel {
  final int id;
  final int studentId;
  final int surahNumber;
  final String surahName;
  final int fromAyah;
  final int toAyah;
  final double? memorizationScore;
  final double? revisionScore;
  final String? notes;
  final DateTime recordedAt;

  MemorizationModel({
    required this.id,
    required this.studentId,
    required this.surahNumber,
    required this.surahName,
    required this.fromAyah,
    required this.toAyah,
    this.memorizationScore,
    this.revisionScore,
    this.notes,
    required this.recordedAt,
  });

  factory MemorizationModel.fromJson(Map<String, dynamic> json) {
    return MemorizationModel(
      id: json['id'],
      studentId: json['studentId'],
      surahNumber: json['surahNumber'],
      surahName: json['surahName'],
      fromAyah: json['fromAyah'],
      toAyah: json['toAyah'],
      memorizationScore: json['memorizationScore'] != null ? (json['memorizationScore'] as num).toDouble() : null,
      revisionScore: json['revisionScore'] != null ? (json['revisionScore'] as num).toDouble() : null,
      notes: json['notes'],
      recordedAt: DateTime.parse(json['recordedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'surahNumber': surahNumber,
      'surahName': surahName,
      'fromAyah': fromAyah,
      'toAyah': toAyah,
      'memorizationScore': memorizationScore,
      'revisionScore': revisionScore,
      'notes': notes,
    };
  }
}
