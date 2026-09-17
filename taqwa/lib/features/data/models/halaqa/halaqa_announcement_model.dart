/// One piece of news about a halaqa, as returned by
/// GET /halaqa-announcements/mine and /halaqa-announcements/halaqa/:id.
///
/// Parsing is deliberately forgiving, like [NotificationModel]: a card on a
/// dashboard must render whatever arrived rather than throw and take the
/// screen with it.
class HalaqaAnnouncementModel {
  final int id;
  final int halaqaId;
  final String halaqaName;
  final String title;
  final String body;
  final String authorName;
  final DateTime createdAt;

  const HalaqaAnnouncementModel({
    required this.id,
    required this.halaqaId,
    required this.halaqaName,
    required this.title,
    required this.body,
    required this.authorName,
    required this.createdAt,
  });

  factory HalaqaAnnouncementModel.fromJson(Map<String, dynamic> json) {
    final halaqa = json['halaqa'] as Map<String, dynamic>?;
    final author = json['author'] as Map<String, dynamic>?;

    return HalaqaAnnouncementModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      halaqaId: (json['halaqaId'] as num?)?.toInt() ?? 0,
      halaqaName: (halaqa?['name'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      authorName: (author?['fullName'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  /// dd/MM/yyyy, the same form the attendance and notes screens show.
  String get formattedDate {
    final d = createdAt;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
