import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/enums/memorization_subject.dart';
import 'package:taqwa/core/enums/memorization_type.dart';
import 'package:taqwa/core/utils/last_session.dart';
import 'package:taqwa/core/widgets/last_session_card.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

LastSession _session({
  String status = 'PRESENT',
  List<LastSessionEntry> entries = const [],
}) {
  return LastSession(
    date: DateTime.utc(2026, 8, 7),
    status: status,
    entries: entries,
  );
}

void main() {
  testWidgets('shows the day the child was last marked', (tester) async {
    await tester.pumpWidget(_host(LastSessionCard(session: _session())));
    await tester.pumpAndSettle();

    expect(find.text('07/08/2026'), findsOneWidget);
  });

  testWidgets('labels a day the child attended', (tester) async {
    await tester.pumpWidget(_host(LastSessionCard(session: _session())));
    await tester.pumpAndSettle();

    expect(find.text('حاضر'), findsOneWidget);
  });

  testWidgets('labels a day the child missed', (tester) async {
    await tester.pumpWidget(
      _host(LastSessionCard(session: _session(status: 'ABSENT'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('غائب'), findsOneWidget);
  });

  testWidgets('labels a day the child arrived late', (tester) async {
    await tester.pumpWidget(
      _host(LastSessionCard(session: _session(status: 'LATE'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('متأخر'), findsOneWidget);
  });

  testWidgets('counts new memorization in pages', (tester) async {
    await tester.pumpWidget(
      _host(
        LastSessionCard(
          session: _session(
            entries: const [
              LastSessionEntry(
                surahNumber: 2,
                amount: 3,
                type: MemorizationType.hifz,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حفظ · 3 صفحة'), findsOneWidget);
    expect(find.text('سورة البقرة'), findsOneWidget);
  });

  testWidgets('counts revision in hizbs', (tester) async {
    await tester.pumpWidget(
      _host(
        LastSessionCard(
          session: _session(
            entries: const [
              LastSessionEntry(
                surahNumber: 18,
                amount: 2,
                type: MemorizationType.majorReview,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراجعة كبرى · 2 حزب'), findsOneWidget);
  });

  testWidgets('lists every entry recorded that day', (tester) async {
    await tester.pumpWidget(
      _host(
        LastSessionCard(
          session: _session(
            entries: const [
              LastSessionEntry(
                surahNumber: 2,
                amount: 3,
                type: MemorizationType.hifz,
              ),
              LastSessionEntry(
                surahNumber: 18,
                amount: 1,
                type: MemorizationType.minorReview,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سورة البقرة'), findsOneWidget);
    expect(find.text('سورة الكهف'), findsOneWidget);
  });

  testWidgets('falls back to the surah number when the name is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LastSessionCard(
          session: _session(
            entries: const [
              LastSessionEntry(
                surahNumber: 0,
                amount: 3,
                type: MemorizationType.hifz,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سورة رقم 0'), findsOneWidget);
  });

  testWidgets('says so when nothing was recited that day', (tester) async {
    await tester.pumpWidget(
      _host(LastSessionCard(session: _session(status: 'ABSENT'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('لم يُسجل حفظ في هذا اليوم'), findsOneWidget);
  });

  testWidgets('says so when no attendance has been taken yet', (tester) async {
    await tester.pumpWidget(_host(const LastSessionCard(session: null)));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد سجل حضور بعد'), findsOneWidget);
  });

  testWidgets('shows the hadith reference and counts in hadiths', (tester) async {
    await tester.pumpWidget(
      _host(
        LastSessionCard(
          session: _session(
            entries: const [
              LastSessionEntry(
                amount: 2,
                type: MemorizationType.hifz,
                subject: MemorizationSubject.hadith,
                hadithReference: 'حديث النية',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حفظ · 2 حديث'), findsOneWidget);
    expect(find.text('حديث النية'), findsOneWidget);
  });
}
