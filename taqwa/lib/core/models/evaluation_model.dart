class EvaluationModel {
  final int id;
  final int studentId;
  final int teacherId;
  final double? memorizationScore;
  final double? tajweedScore;
  final double? fluencyScore;
  final double? disciplineScore;
  final double? overallScore;
  final String? notes;
  final DateTime createdAt;
  final String? teacherName;

  EvaluationModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.memorizationScore,
    this.tajweedScore,
    this.fluencyScore,
    this.disciplineScore,
    this.overallScore,
    this.notes,
    required this.createdAt,
    this.teacherName,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    String? tName;
    if (json['teacher'] != null && json['teacher']['user'] != null) {
      tName = json['teacher']['user']['fullName'];
    }

    return EvaluationModel(
      id: json['id'],
      studentId: json['studentId'],
      teacherId: json['teacherId'],
      memorizationScore: json['memorizationScore'] != null ? (json['memorizationScore'] as num).toDouble() : null,
      tajweedScore: json['tajweedScore'] != null ? (json['tajweedScore'] as num).toDouble() : null,
      fluencyScore: json['fluencyScore'] != null ? (json['fluencyScore'] as num).toDouble() : null,
      disciplineScore: json['disciplineScore'] != null ? (json['disciplineScore'] as num).toDouble() : null,
      overallScore: json['overallScore'] != null ? (json['overallScore'] as num).toDouble() : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      teacherName: tName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'teacherId': teacherId,
      'memorizationScore': memorizationScore,
      'tajweedScore': tajweedScore,
      'fluencyScore': fluencyScore,
      'disciplineScore': disciplineScore,
      'overallScore': overallScore,
      'notes': notes,
    };
  }
}
