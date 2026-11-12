import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/manager/presentation/pages/justification_list_page.dart';

import '../../helpers/stub_api.dart';

class _Admin extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    user: UserModel(id: 1, fullName: 'المدير العام', role: UserRole.admin),
    isAuthenticated: true,
  );
}

Map<String, dynamic> _student(String name, {int? halaqaId, String? halaqa}) => {
  'user': {'fullName': name},
  'halaqa': halaqaId == null ? null : {'id': halaqaId, 'name': halaqa},
};

/// Shaped like GET /absence-justifications/unjustified with no managerId.
final _pending = [
  {
    'id': 10,
    'studentId': 1,
    'date': '2026-11-10',
    'status': 'ABSENT',
    'student': _student('طالب أ', halaqaId: 2, halaqa: 'حلقة العصر'),
  },
  {
    'id': 11,
    'studentId': 2,
    'date': '2026-11-09',
    'status': 'LATE',
    'student': _student('طالب ب', halaqaId: 1, halaqa: 'حلقة الفجر'),
  },
  {
    'id': 12,
    'studentId': 3,
    'date': '2026-11-08',
    'status': 'ABSENT',
    'student': _student('طالب ج'),
  },
];

/// Shaped like GET /absence-justifications with no managerId.
final _justified = [
  {
    'id': 5,
    'studentId': 1,
    'attendanceId': 9,
    'managerId': 3,
    'reasonType': 'ILLNESS',
    'attendance': {'id': 9, 'date': '2026-11-01', 'status': 'ABSENT'},
    'student': _student('طالب أ', halaqaId: 2, halaqa: 'حلقة العصر'),
    'manager': {
      'user': {'fullName': 'مدير تجريبي'},
    },
  },
];

late StubApi _api;

Widget _host() => ProviderScope(
  overrides: [authProvider.overrideWith(_Admin.new)],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) =>
        const MaterialApp(home: JustificationListPage(allHalaqas: true)),
  ),
);

/// Phone-sized surface; the test font draws Arabic as full squares, so row
/// overflow reports are dropped while every other error still fails.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  setUp(() {
    _api = StubApi.install((r) {
      if (r.method != 'GET') return (404, {'message': 'not stubbed'});
      if (r.path == '/absence-justifications/unjustified') {
        return (200, _pending);
      }
      if (r.path == '/absence-justifications') return (200, _justified);
      return (404, {'message': 'not stubbed'});
    });
  });

  testWidgets('asks for every halaqa, with no manager id', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final calls = _api.sent('GET', '/absence-justifications');
    expect(calls, hasLength(2));
    for (final call in calls) {
      expect(call.queryParameters.containsKey('managerId'), isFalse);
    }
  });

  testWidgets('groups pending absences by halaqa, unassigned last', (
    tester,
  ) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final asr = tester.getTopLeft(find.text('حلقة العصر')).dy;
    final fajr = tester.getTopLeft(find.text('حلقة الفجر')).dy;
    final none = tester.getTopLeft(find.text('غير مسجلين')).dy;
    // Sorted by name: العصر before الفجر, the unassigned bucket at the end.
    expect(asr, lessThan(fajr));
    expect(fajr, lessThan(none));
    expect(find.text('حالة واحدة'), findsNWidgets(3));
  });

  testWidgets('pending rows are read-only for the admin', (tester) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_calendar_outlined), findsNothing);
    await tester.tap(find.text('طالب أ'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a justified row names the manager who recorded it', (
    tester,
  ) async {
    _phoneScreen(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مبررة (1)'));
    await tester.pumpAndSettle();

    expect(find.text('حلقة العصر'), findsOneWidget);
    expect(find.text('مدير تجريبي'), findsOneWidget);
    expect(find.text('سجّله'), findsOneWidget);
  });
}
