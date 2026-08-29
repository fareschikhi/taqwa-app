import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/notification_model.dart';

void main() {
  test('parses the shape the API returns', () {
    final model = NotificationModel.fromJson({
      'id': 3,
      'userId': 9,
      'title': 'غياب',
      'body': 'تم تسجيل غياب Djamel Kaddour اليوم',
      'isRead': false,
      'createdAt': '2026-08-29T17:12:40.214Z',
    });

    expect(model.id, 3);
    expect(model.title, 'غياب');
    expect(model.body, 'تم تسجيل غياب Djamel Kaddour اليوم');
    expect(model.isRead, isFalse);
    expect(model.createdAt.year, 2026);
  });

  test('a missing isRead reads as unread rather than throwing', () {
    final model = NotificationModel.fromJson({
      'id': 3,
      'title': 'غياب',
      'body': 'x',
      'createdAt': '2026-08-29T17:12:40.214Z',
    });

    expect(model.isRead, isFalse);
  });

  test('an unparsable date falls back to now rather than throwing', () {
    final model = NotificationModel.fromJson({
      'id': 3,
      'title': 'غياب',
      'body': 'x',
      'createdAt': 'not a date',
    });

    expect(model.createdAt, isA<DateTime>());
  });
}
