import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/phone_field.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Form(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('starts on +213 and stores an Algerian number in local form',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_host(PhoneField(controller: controller)));

    expect(find.text('+213'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '551234567');
    expect(controller.text, '0551234567');
  });

  testWidgets('another picked country is stored with its + code',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_host(PhoneField(controller: controller)));

    await tester.tap(find.text('+213'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المغرب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '612345678');

    expect(find.text('+212'), findsOneWidget);
    expect(controller.text, '+212612345678');
  });

  testWidgets('a prefilled number is split into its country and the rest',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_host(PhoneField(controller: controller)));

    // An edit form fills its controller once the record has loaded.
    controller.text = '+966501234567';
    await tester.pump();

    expect(find.text('+966'), findsOneWidget);
    expect(find.text('501234567'), findsOneWidget);
    expect(controller.text, '+966501234567');
  });

  testWidgets('an untouched old number is sent back as it was',
      (tester) async {
    final controller = TextEditingController(text: '1001');
    await tester.pumpWidget(_host(PhoneField(controller: controller)));

    expect(find.text('1001'), findsOneWidget);
    expect(controller.text, '1001');
  });
}
