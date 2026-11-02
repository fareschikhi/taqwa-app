import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';
import 'package:taqwa/core/widgets/list_layout.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('toggle reports the layout tapped, not the current one',
      (tester) async {
    final picked = <ListLayout>[];
    await tester.pumpWidget(_host(ListLayoutToggle(
      value: ListLayout.list,
      onChanged: picked.add,
    )));

    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump();

    expect(picked, [ListLayout.grid]);
  });

  // The app runs LTR and right-aligns by hand, so the first card must still
  // land on the right.
  testWidgets('grid row fills from the right', (tester) async {
    await tester.pumpWidget(_host(const CardGridRow(
      columns: 2,
      children: [Text('first'), Text('second')],
    )));

    expect(
      tester.getCenter(find.text('first')).dx,
      greaterThan(tester.getCenter(find.text('second')).dx),
    );
  });

  test('two columns on a phone, more on a tablet', () {
    expect(cardGridColumns(358), 2);
    expect(cardGridColumns(700), 3);
    expect(cardGridColumns(1000), 4);
  });

  test('store remembers each page apart and defaults to list', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ListLayoutStore.read('a'), ListLayout.list);

    await ListLayoutStore.write('a', ListLayout.grid);
    expect(await ListLayoutStore.read('a'), ListLayout.grid);
    expect(await ListLayoutStore.read('b'), ListLayout.list);
  });

  testWidgets('compact action row is icon-only and fires each callback',
      (tester) async {
    var edited = false, deleted = false, toggled = false;
    await tester.pumpWidget(_host(SizedBox(
      width: 130,
      child: CardActionRow(
        compact: true,
        isActive: true,
        onToggleActive: () => toggled = true,
        onDelete: () => deleted = true,
        onEdit: () => edited = true,
        onTelegram: () {},
      ),
    )));

    expect(find.text('تعديل'), findsNothing);
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();

    expect(toggled, isTrue);
    expect(deleted, isTrue);
    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });
}
