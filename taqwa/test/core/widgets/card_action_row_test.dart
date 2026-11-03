import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/card_action_row.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  pointsActionTests();
  testWidgets('renders three controls and fires each callback', (tester) async {
    var edited = false, deleted = false, toggled = false;

    await tester.pumpWidget(_host(CardActionRow(
      isActive: true,
      onToggleActive: () => toggled = true,
      onDelete: () => deleted = true,
      onEdit: () => edited = true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('تعديل'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.tap(find.text('تعديل'));
    await tester.pump();

    expect(toggled, isTrue);
    expect(deleted, isTrue);
    expect(edited, isTrue);
  });

  testWidgets('shows the red block icon when inactive', (tester) async {
    await tester.pumpWidget(_host(CardActionRow(
      isActive: false,
      onToggleActive: () {},
      onDelete: () {},
      onEdit: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  // Halaqas are not users and have no isActive column, so the toggle must
  // disappear rather than render disabled.
  testWidgets('omits the toggle when isActive is null', (tester) async {
    await tester.pumpWidget(_host(CardActionRow(
      onDelete: () {},
      onEdit: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.block), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
  });

  testWidgets('shows a Telegram button only when onTelegram is given',
      (tester) async {
    var messaged = false;
    await tester.pumpWidget(_host(CardActionRow(
      onDelete: () {},
      onEdit: () {},
      onTelegram: () => messaged = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('تيليجرام'));
    expect(messaged, isTrue);

    await tester.pumpWidget(_host(CardActionRow(
      onDelete: () {},
      onEdit: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byTooltip('تيليجرام'), findsNothing);
  });
}

void pointsActionTests() {
  // Teachers have no details page, so their card is where the admin reaches
  // their points; other cards don't show the button.
  for (final compact in [false, true]) {
    testWidgets('a points action appears only when given (compact: $compact)', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _host(
          CardActionRow(
            onDelete: () {},
            onEdit: () {},
            onPoints: () => opened = true,
            compact: compact,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('النقاط'));
      expect(opened, isTrue);

      await tester.pumpWidget(
        _host(CardActionRow(onDelete: () {}, onEdit: () {}, compact: compact)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('النقاط'), findsNothing);
    });
  }
}
