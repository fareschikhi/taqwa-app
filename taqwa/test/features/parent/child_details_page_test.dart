import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/selected_student_provider.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/data/models/parent/parent_child_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/parent/presentation/pages/child_details_page.dart';

/// Profile and progress answer `{}`; the points route answers from
/// [pointsReplies] in order, a null meaning a 500.
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.pointsReplies);
  final List<Map<String, dynamic>?> pointsReplies;
  int pointsCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const json = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path.contains('/points/')) {
      final reply = pointsReplies[pointsCalls++];
      if (reply == null) {
        return ResponseBody.fromString('{"message":"x"}', 500, headers: json);
      }
      return ResponseBody.fromString(jsonEncode(reply), 200, headers: json);
    }
    return ResponseBody.fromString('{}', 200, headers: json);
  }

  @override
  void close({bool force = false}) {}
}

class _FixedChild extends SelectedStudentNotifier {
  @override
  SelectedStudentState build() {
    const child = ParentChildModel(id: 30, fullName: 'طالب تجريبي');
    return SelectedStudentState(students: const [child], selected: child);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );

  // Pulling to refresh the same child must not throw away the points already
  // on screen: if the refresh's points call fails, the card stays.
  testWidgets('a same-child refresh keeps the points card', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // The test font draws every glyph a full em wide, so the info boxes'
    // label rows overflow here as they don't on a phone. Not this test's
    // concern; anything else still fails it.
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      reportError?.call(details);
    };

    final adapter = _RoutingAdapter([
      {'total': '-0.5', 'entries': []},
      null,
    ]);
    DioClient.instance.httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [selectedStudentProvider.overrideWith(_FixedChild.new)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => const MaterialApp(home: ChildDetailsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PointsBalanceCard), findsOneWidget);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 600),
      1000,
    );
    await tester.pumpAndSettle();

    expect(adapter.pointsCalls, 2, reason: 'the refresh did reload points');
    FlutterError.onError = reportError;
    expect(find.byType(PointsBalanceCard), findsOneWidget);
  });
}
