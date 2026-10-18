import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/telegram.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  group('telegramUri', () {
    test('turns a local Algerian mobile into an international t.me link', () {
      expect(
        telegramUri('0551 23 45 67').toString(),
        'https://t.me/+213551234567',
      );
    });

    test('keeps an international number and drops the 00 prefix', () {
      expect(
        telegramUri('+213551234567').toString(),
        'https://t.me/+213551234567',
      );
      expect(
        telegramUri('00213551234567').toString(),
        'https://t.me/+213551234567',
      );
    });

    test('is null when there is no usable number', () {
      expect(telegramUri(null), isNull);
      expect(telegramUri(''), isNull);
      expect(telegramUri('12'), isNull);
    });
  });

  group('TelegramButton', () {
    testWidgets('shows the button for a usable number', (tester) async {
      await tester.pumpWidget(_host(const TelegramButton(phone: '0551234567')));

      expect(find.text('تواصل عبر تيليجرام'), findsOneWidget);
    });

    testWidgets('renders nothing without a usable number', (tester) async {
      await tester.pumpWidget(_host(const TelegramButton(phone: null)));

      expect(find.text('تواصل عبر تيليجرام'), findsNothing);
    });
  });
}
