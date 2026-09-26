import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';

void main() {
  test('parses the shape the API returns', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'غياب المعلم',
      'body': 'الحلقة معطلة غدا',
      'createdAt': '2026-09-17T09:12:40.214Z',
      'halaqa': {'id': 4, 'name': 'حلقة النور'},
      'author': {'id': 17, 'fullName': 'Ahmed Bencheikh'},
    });

    expect(model.id, 31);
    expect(model.halaqaId, 4);
    expect(model.halaqaName, 'حلقة النور');
    expect(model.title, 'غياب المعلم');
    expect(model.body, 'الحلقة معطلة غدا');
    expect(model.authorName, 'Ahmed Bencheikh');
    expect(model.createdAt.year, 2026);
  });

  test('lists every halaqa of an all-halaqas post', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'عطلة',
      'body': 'الحلقات معطلة غدا',
      'createdAt': '2026-09-24T09:12:40.214Z',
      'batchId': '6f1c2a9e-0000-4000-8000-000000000000',
      'halaqa': {'id': 4, 'name': 'حلقة النور'},
      'halaqas': [
        {'id': 4, 'name': 'حلقة النور'},
        {'id': 7, 'name': 'حلقة الفجر'},
      ],
    });

    expect(model.batchId, isNotNull);
    expect(model.halaqaNames, ['حلقة النور', 'حلقة الفجر']);
    expect(model.halaqaLabel, 'حلقة النور، حلقة الفجر');
  });

  // /halaqa/:id sends no `halaqas`: the row's own halaqa is the whole list.
  test('falls back to its own halaqa without a halaqas list', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'x',
      'body': 'y',
      'createdAt': '2026-09-24T09:12:40.214Z',
      'halaqa': {'id': 4, 'name': 'حلقة النور'},
    });

    expect(model.batchId, isNull);
    expect(model.halaqaLabel, 'حلقة النور');
  });

  test('formats the date the way the rest of the app does', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'x',
      'body': 'y',
      'createdAt': '2026-09-07T09:12:40.214Z',
    });

    expect(model.formattedDate, '07/09/2026');
  });

  // The nesting is absent on a payload that did not include it. A dashboard
  // card must still render rather than throw.
  test('tolerates a missing halaqa and author', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'x',
      'body': 'y',
      'createdAt': '2026-09-17T09:12:40.214Z',
    });

    expect(model.halaqaName, '');
    expect(model.authorName, '');
  });

  test('an unparsable date falls back to now rather than throwing', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'id': 31,
      'halaqaId': 4,
      'title': 'x',
      'body': 'y',
      'createdAt': 'not a date',
    });

    expect(model.createdAt.year, DateTime.now().year);
  });

  test('a missing id reads as zero rather than throwing', () {
    final model = HalaqaAnnouncementModel.fromJson({
      'title': 'x',
      'body': 'y',
      'createdAt': '2026-09-17T09:12:40.214Z',
    });

    expect(model.id, 0);
    expect(model.halaqaId, 0);
  });
}
