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

  /// Set when this was posted to all halaqas at once; edit and delete then
  /// act on every halaqa it went to.
  final String? batchId;

  /// Every halaqa this item reached, as far as the viewer can see: the feed
  /// folds an all-halaqas post into one item and lists its halaqas here.
  final List<String> halaqaNames;

  const HalaqaAnnouncementModel({
    required this.id,
    required this.halaqaId,
    required this.halaqaName,
    required this.title,
    required this.body,
    required this.authorName,
    required this.createdAt,
    this.batchId,
    this.halaqaNames = const [],
  });

  factory HalaqaAnnouncementModel.fromJson(Map<String, dynamic> json) {
    final halaqa = json['halaqa'] as Map<String, dynamic>?;
    final author = json['author'] as Map<String, dynamic>?;
    final halaqaName = (halaqa?['name'] as String?) ?? '';
    final halaqas = json['halaqas'];

    return HalaqaAnnouncementModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      halaqaId: (json['halaqaId'] as num?)?.toInt() ?? 0,
      halaqaName: halaqaName,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      authorName: (author?['fullName'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      batchId: json['batchId'] as String?,
      // One halaqa's history route sends no `halaqas`; its own halaqa is the
      // whole list then.
      halaqaNames: halaqas is List
          ? halaqas
                .whereType<Map<String, dynamic>>()
                .map((h) => (h['name'] as String?) ?? '')
                .where((n) => n.isNotEmpty)
                .toList()
          : [if (halaqaName.isNotEmpty) halaqaName],
    );
  }

  /// Which halaqas this went to, for the line under the title.
  String get halaqaLabel => halaqaNames.join('، ');

  /// dd/MM/yyyy, the same form the attendance and notes screens show.
  String get formattedDate {
    final d = createdAt;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
