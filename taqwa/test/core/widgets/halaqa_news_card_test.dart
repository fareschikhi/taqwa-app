import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/halaqa_news_card.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';

HalaqaAnnouncementModel _news(int id, String title) =>
    HalaqaAnnouncementModel.fromJson({
      'id': id,
      'halaqaId': 4,
      'title': title,
      'body': 'الحلقة معطلة غدا',
      'createdAt': '2026-09-17T09:12:40.214Z',
      'halaqa': {'id': 4, 'name': 'حلقة النور'},
    });

Future<void> _pump(
  WidgetTester tester, {
  ValueChanged<HalaqaAnnouncementModel>? onEdit,
  ValueChanged<HalaqaAnnouncementModel>? onDelete,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HalaqaNewsCard(
                announcements: [_news(1, 'غياب المعلم'), _news(2, 'مسابقة')],
                canCompose: onEdit != null,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a reader sees no edit or delete icons', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('each row hands its own announcement to edit and delete', (
    tester,
  ) async {
    final edited = <int>[];
    final deleted = <int>[];
    await _pump(
      tester,
      onEdit: (a) => edited.add(a.id),
      onDelete: (a) => deleted.add(a.id),
    );

    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.tap(find.byIcon(Icons.delete_outline).first);

    expect(edited, [2]);
    expect(deleted, [1]);
    expect(tester.takeException(), isNull);
  });
}
