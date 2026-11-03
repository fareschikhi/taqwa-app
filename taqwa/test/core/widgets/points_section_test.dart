import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/widgets/app_text_field.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/core/widgets/points_section.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';

import '../../helpers/stub_api.dart';

class _FixedAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    user: UserModel(id: 2, fullName: 'معلم', role: UserRole.teacher),
    isAuthenticated: true,
  );
}

Future<void> _pump(WidgetTester tester, Widget section) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(_FixedAuth.new)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: section)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _adjust = find.text('تعديل النقاط');

void main() {
  late StubApi api;
  setUp(() {
    api = StubApi.install((r) {
      if (r.method == 'GET') {
        return (200, {'userId': 70, 'total': '3', 'entries': []});
      }
      return (201, {});
    });
  });

  Widget section({bool canAdjust = false, bool hide = true}) => PointsSection(
    load: () => PointsRepository().forStudent(7),
    canAdjust: canAdjust,
    hideWhenUnavailable: hide,
  );

  testWidgets('offers the adjust button only when allowed', (tester) async {
    await _pump(tester, section(canAdjust: true));
    expect(find.byType(PointsBalanceCard), findsOneWidget);
    expect(_adjust, findsOneWidget);
  });

  testWidgets('a read-only section has no adjust button', (tester) async {
    await _pump(tester, section());
    expect(find.byType(PointsBalanceCard), findsOneWidget);
    expect(_adjust, findsNothing);
  });

  // Staff outside the student's halaqa get a 403: the section stays off and
  // the page around it carries on.
  testWidgets('a refused load renders nothing', (tester) async {
    api.reply = (_) => (403, {'message': 'لا يمكنك'});
    await _pump(tester, section(canAdjust: true));
    expect(find.byType(PointsBalanceCard), findsNothing);
    expect(_adjust, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused load can show why and retry', (tester) async {
    api.reply = (_) => (500, {'message': 'x'});
    await _pump(tester, section(hide: false));
    expect(find.text('تعذر تحميل النقاط'), findsOneWidget);

    api.reply = (_) => (200, {'userId': 70, 'total': '3', 'entries': []});
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.byType(PointsBalanceCard), findsOneWidget);
  });

  testWidgets('adjusting posts to the account and reloads', (tester) async {
    await _pump(tester, section(canAdjust: true));

    await tester.tap(_adjust);
    await tester.pumpAndSettle();
    await tester.tap(find.text('خصم'));
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'العدد',
        ),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(api.sent('POST', '/points').single.data, {
      'userId': 70,
      'amount': -2.0,
    });
    expect(api.sent('GET', '/points/student/7'), hasLength(2));
    expect(find.text('تم تعديل النقاط'), findsOneWidget);
  });
}
