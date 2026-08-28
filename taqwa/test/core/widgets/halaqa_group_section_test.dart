import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/halaqa_group_section.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('shows the halaqa name and its student count', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 8,
          isExpanded: true,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('8 طلاب'), findsOneWidget);
  });

  testWidgets('renders its children when expanded', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 1,
          isExpanded: true,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
  });

  testWidgets('hides its children when collapsed', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 1,
          isExpanded: false,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('أحمد'), findsNothing);
  });

  testWidgets('fires onToggle when the header is tapped', (tester) async {
    var toggled = false;

    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 1,
          isExpanded: true,
          onToggle: () => toggled = true,
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('حلقة الفجر'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('uses the singular wording for one student', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 1,
          isExpanded: true,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طالب واحد'), findsOneWidget);
  });

  testWidgets('uses the dual wording for two students', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 2,
          isExpanded: true,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طالبان'), findsOneWidget);
  });

  testWidgets('uses the accusative wording past ten students', (tester) async {
    await tester.pumpWidget(
      _host(
        HalaqaGroupSection(
          title: 'حلقة الفجر',
          count: 11,
          isExpanded: true,
          onToggle: () {},
          children: const [Text('أحمد')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('11 طالباً'), findsOneWidget);
  });
}
