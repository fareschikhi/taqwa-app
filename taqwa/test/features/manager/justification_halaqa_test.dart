import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/absence_justification_model.dart';
import 'package:taqwa/features/data/models/unjustified_attendance_model.dart';
import 'package:taqwa/features/manager/presentation/pages/justification_list_page.dart';

/// The student object both justification endpoints embed, with or without
/// the halaqa the backend now includes.
Map<String, dynamic> student({Map<String, dynamic>? halaqa}) => {
  'user': {'fullName': 'طالب تجريبي'},
  'halaqa': halaqa,
};

void main() {
  group('UnjustifiedAttendanceModel halaqa', () {
    test('reads the embedded halaqa', () {
      final m = UnjustifiedAttendanceModel.fromJson({
        'id': 1,
        'studentId': 7,
        'student': student(halaqa: {'id': 3, 'name': 'حلقة الفجر'}),
      });

      expect(m.halaqaId, 3);
      expect(m.halaqaName, 'حلقة الفجر');
    });

    test('is null for a student in no halaqa', () {
      final m = UnjustifiedAttendanceModel.fromJson({
        'id': 1,
        'studentId': 7,
        'student': student(),
      });

      expect(m.halaqaId, isNull);
      expect(m.halaqaName, isNull);
    });
  });

  group('AbsenceJustificationModel halaqa', () {
    Map<String, dynamic> row(Map<String, dynamic>? halaqa) => {
      'id': 1,
      'studentId': 7,
      'attendanceId': 40,
      'managerId': 2,
      'student': student(halaqa: halaqa),
    };

    test('reads the embedded halaqa', () {
      final m = AbsenceJustificationModel.fromJson(
        row({'id': 3, 'name': 'حلقة الفجر'}),
      );

      expect(m.halaqaId, 3);
      expect(m.halaqaName, 'حلقة الفجر');
    });

    test('is null for a student in no halaqa', () {
      final m = AbsenceJustificationModel.fromJson(row(null));

      expect(m.halaqaId, isNull);
      expect(m.halaqaName, isNull);
    });
  });

  test('caseCountLabel follows Arabic number agreement', () {
    expect(caseCountLabel(1), 'حالة واحدة');
    expect(caseCountLabel(2), 'حالتان');
    expect(caseCountLabel(3), '3 حالات');
    expect(caseCountLabel(10), '10 حالات');
    expect(caseCountLabel(11), '11 حالة');
  });
}
