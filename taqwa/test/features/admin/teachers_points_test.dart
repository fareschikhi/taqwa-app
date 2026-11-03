import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/admin/presentation/pages/teachers_management_page.dart';
import 'package:taqwa/features/data/models/user_model.dart';

import '../../helpers/stub_api.dart';

class _Admin extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    user: UserModel(id: 1, fullName: 'المدير العام', role: UserRole.admin),
    isAuthenticated: true,
  );
}

void main() {
  // Teachers have no details page: the admin reaches a teacher's points from
  // the card, in a sheet loaded by the teacher's *account* id (userId 50),
  // not the teacher-row id (5).
  testWidgets('a teacher card opens that teacher\'s points', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final reportError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      reportError?.call(d);
    };

    final api = StubApi.install((r) {
      if (r.path.startsWith('/points/user/')) {
        return (200, {'userId': 50, 'total': '4', 'entries': []});
      }
      if (r.path.startsWith('/teachers')) {
        return (
          200,
          [
            {
              'id': 5,
              'userId': 50,
              'user': {'id': 50, 'fullName': 'معلم تجريبي', 'role': 'TEACHER'},
              '_count': {'halaqas': 0},
            },
          ],
        );
      }
      return (404, {'message': 'not stubbed'});
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_Admin.new)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              const MaterialApp(home: Scaffold(body: TeachersManagementPage())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('النقاط'));
    await tester.pumpAndSettle();

    FlutterError.onError = reportError;
    expect(api.sent('GET', '/points/user/50'), hasLength(1));
    expect(find.byType(PointsBalanceCard), findsOneWidget);
    expect(find.text('تعديل النقاط'), findsOneWidget);
  });
}
