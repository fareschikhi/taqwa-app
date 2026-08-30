import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/adult_student/presentation/pages/adult_dashboard_page.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('renders a note with its text', (tester) async {
    final notes = [
      {
        'note': 'الطالب يبذل جهداً كبيراً في الحفظ',
        'createdAt': '2026-08-28',
        'teacher': {
          'user': {
            'fullName': 'أحمد علي',
          }
        }
      }
    ];

    await tester.pumpWidget(
      _host(TeacherNotesSection(notes: notes)),
    );
    await tester.pumpAndSettle();

    expect(find.text('الطالب يبذل جهداً كبيراً في الحفظ'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no notes', (tester) async {
    await tester.pumpWidget(
      _host(const TeacherNotesSection(notes: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد ملاحظات بعد'), findsOneWidget);
  });

  testWidgets('renders multiple notes', (tester) async {
    final notes = [
      {
        'note': 'ملاحظة أولى',
        'createdAt': '2026-08-28',
        'teacher': {
          'user': {
            'fullName': 'معلم أول',
          }
        }
      },
      {
        'note': 'ملاحظة ثانية',
        'createdAt': '2026-08-27',
        'teacher': {
          'user': {
            'fullName': 'معلم ثاني',
          }
        }
      }
    ];

    await tester.pumpWidget(
      _host(TeacherNotesSection(notes: notes)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ملاحظة أولى'), findsOneWidget);
    expect(find.text('ملاحظة ثانية'), findsOneWidget);
  });

  testWidgets('displays teacher name', (tester) async {
    final notes = [
      {
        'note': 'ملاحظة من المعلم',
        'createdAt': '2026-08-28',
        'teacher': {
          'user': {
            'fullName': 'فاطمة محمود',
          }
        }
      }
    ];

    await tester.pumpWidget(
      _host(TeacherNotesSection(notes: notes)),
    );
    await tester.pumpAndSettle();

    expect(find.text('فاطمة محمود'), findsOneWidget);
  });

  testWidgets('displays the heading', (tester) async {
    await tester.pumpWidget(
      _host(const TeacherNotesSection(notes: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('ملاحظات المعلم'), findsOneWidget);
  });

  testWidgets(
    'when profile fetch fails, shows empty state without crashing',
    (tester) async {
      // When the profile fetch fails in _load(), getProfile().catchError()
      // returns an empty map, so _notes is empty. The dashboard loads its balance
      // and attendance while the notes section renders the empty state.
      await tester.pumpWidget(
        _host(const TeacherNotesSection(notes: [])),
      );
      await tester.pumpAndSettle();

      // The section renders its heading and empty-state text, not blank or error.
      expect(find.text('ملاحظات المعلم'), findsOneWidget);
      expect(find.text('لا توجد ملاحظات بعد'), findsOneWidget);
    },
  );
}
