import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/note_timeline.dart';
import 'package:taqwa/features/data/models/student_note_model.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

StudentNoteModel _note(int id, DateTime local, String text) => StudentNoteModel(
  id: id,
  studentId: 1,
  teacherId: 1,
  note: text,
  createdAt: local.toUtc().toIso8601String(),
  teacherName: 'الأستاذ أحمد',
);

void main() {
  final now = DateTime(2026, 9, 25, 18, 0);

  testWidgets('shows each note under its day with the time it was written', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NoteTimeline(
          now: now,
          notes: [
            _note(1, DateTime(2026, 9, 25, 16, 30), 'حفظ جيداً'),
            _note(2, DateTime(2026, 9, 24, 9, 5), 'تأخر عن الحلقة'),
            _note(3, DateTime(2026, 9, 10, 17, 45), 'مراجعة سورة البقرة'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('أمس'), findsOneWidget);
    expect(find.text('10/09/2026'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('حفظ جيداً'), findsOneWidget);
    expect(find.text('الأستاذ أحمد'), findsNWidgets(3));
  });

  testWidgets('puts two notes of one day under a single heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NoteTimeline(
          now: now,
          notes: [
            _note(1, DateTime(2026, 9, 25, 8), 'أ'),
            _note(2, DateTime(2026, 9, 25, 9), 'ب'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اليوم'), findsOneWidget);
    // Newest first.
    final top = tester.getTopLeft(find.text('ب')).dy;
    final below = tester.getTopLeft(find.text('أ')).dy;
    expect(top, lessThan(below));
  });
}
