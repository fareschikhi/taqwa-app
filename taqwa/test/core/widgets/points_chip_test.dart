import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/points_chip.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('shows a loss in the error color', (tester) async {
    await tester.pumpWidget(_host(const PointsChip(points: -1)));
    expect(find.text(formatPoints(-1)), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(formatPoints(-1))).style?.color,
      AppColors.error,
    );
  });

  testWidgets('shows a gain in the primary color', (tester) async {
    await tester.pumpWidget(_host(const PointsChip(points: 2.5)));
    expect(
      tester.widget<Text>(find.text(formatPoints(2.5))).style?.color,
      AppColors.primary,
    );
  });
}
