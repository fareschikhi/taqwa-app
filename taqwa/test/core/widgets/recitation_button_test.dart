import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/widgets/attendance_controls.dart';

Future<int> _pumpButton(
  WidgetTester tester, {
  String label = 'لم يحفظ',
  String? subLabel = '50 دج',
  bool selected = false,
  bool highlighted = false,
  bool enabled = true,
  bool strikethrough = true,
  bool showBadge = false,
}) async {
  var taps = 0;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: RecitationButton(
            icon: Icons.menu_book_outlined,
            label: label,
            subLabel: subLabel,
            color: AppColors.error,
            selected: selected,
            highlighted: highlighted,
            enabled: enabled,
            strikethrough: strikethrough,
            showBadge: showBadge,
            onTap: () => taps++,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(label));
  await tester.pump();
  return taps;
}

/// The colour the button painted its own label in.
Color? _labelColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  // Both controls carry their label under the icon, which is what makes the
  // pair read as one set of controls.
  testWidgets('shows the label on one line under the icon', (tester) async {
    await _pumpButton(tester);

    expect(find.text('لم يحفظ'), findsOneWidget);
    expect(tester.widget<Text>(find.text('لم يحفظ')).maxLines, 1);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  group('fee line', () {
    // Slash-joined onto the label this needs 205w, and the button gets 159 —
    // so it lives on its own line rather than shrinking the money value.
    testWidgets('sits under the label when the halaqa charges', (tester) async {
      await _pumpButton(tester);

      expect(find.text('50 دج'), findsOneWidget);
    });

    testWidgets('is absent when a missed recitation is free', (tester) async {
      await _pumpButton(tester, subLabel: null);

      expect(find.textContaining('دج'), findsNothing);
      expect(find.text('لم يحفظ'), findsOneWidget);
    });

    testWidgets('takes the filled ink along with the label', (tester) async {
      await _pumpButton(tester, selected: true);

      expect(_labelColor(tester, '50 دج'), AppColors.onError);
    });
  });

  testWidgets('fills with its own colour once chosen', (tester) async {
    await _pumpButton(tester, selected: true);

    expect(_labelColor(tester, 'لم يحفظ'), AppColors.onError);
  });

  // An absent student is already charged for the absence, so he must not be
  // chargeable a second time for not reciting.
  group('when disabled', () {
    testWidgets('ignores a tap', (tester) async {
      expect(await _pumpButton(tester, enabled: false), 0);
    });

    testWidgets('takes a tap once it is enabled again', (tester) async {
      expect(await _pumpButton(tester), 1);
    });

    // Otherwise an absent student's row would still show a red, apparently
    // active fine that he is not actually being charged.
    testWidgets('does not paint itself as chosen', (tester) async {
      await _pumpButton(tester, selected: true, enabled: false);

      expect(_labelColor(tester, 'لم يحفظ'), isNot(AppColors.onError));
    });
  });

  // The memorization button uses this to show it already holds today's
  // recitation, without filling like the toggle does.
  testWidgets('a highlighted button keeps its own ink rather than filling', (
    tester,
  ) async {
    await _pumpButton(tester, highlighted: true, showBadge: true);

    expect(_labelColor(tester, 'لم يحفظ'), AppColors.error);
  });

  group('attendanceColors', () {
    // White on the amber of a late mark sits near 2:1, which is unreadable on
    // a phone outdoors — and outdoors is where attendance gets marked.
    test('gives the late amber dark ink rather than white', () {
      expect(attendanceColors(AttendanceStatus.late).ink, AppColors.onSurface);
      expect(attendanceColors(AttendanceStatus.late).fill, AppColors.late);
    });

    test('gives the filled marks their own colours', () {
      expect(
        attendanceColors(AttendanceStatus.present).fill,
        AppColors.present,
      );
      expect(attendanceColors(AttendanceStatus.absent).fill, AppColors.absent);
    });
  });
}
