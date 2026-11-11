import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/widgets/last_seen_label.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  // The parent nobody has reached yet is the one staff are looking for.
  testWidgets('flags a parent who never opened the app in the error color', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const LastSeenLabel(lastSeen: null)));
    final text = find.text('لم يدخل التطبيق بعد');
    expect(text, findsOneWidget);
    expect(tester.widget<Text>(text).style?.color, AppColors.error);
  });

  testWidgets('shows a recent visit in the quiet text color', (tester) async {
    await tester.pumpWidget(
      _host(LastSeenLabel(lastSeen: DateTime.now())),
    );
    final text = find.text('آخر دخول: اليوم');
    expect(text, findsOneWidget);
    expect(tester.widget<Text>(text).style?.color, AppColors.onSurfaceVariant);
  });
}
