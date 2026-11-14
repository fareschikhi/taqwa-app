import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';

/// برنامج التسميع is an admin opt-in per student, read by the admin form and
/// by the teacher's recitation sheet.
void main() {
  test('both student models read tracksTasmee, nested or flat', () {
    final admin = StudentModel.fromJson({
      'id': 3,
      'user': {'fullName': 'أحمد'},
      'tracksTasmee': true,
    });
    expect(admin.tracksTasmee, isTrue);

    final nested = StudentModel.fromJson({
      'id': 3,
      'fullName': 'أحمد',
      'student': {'tracksTasmee': true},
    });
    expect(nested.tracksTasmee, isTrue);

    final teacher = TeacherStudentModel.fromJson({
      'id': 3,
      'fullName': 'أحمد',
      'tracksTasmee': true,
    });
    expect(teacher.tracksTasmee, isTrue);
  });

  test('a payload without the flag reads as not in the program', () {
    expect(StudentModel.fromJson({'id': 3}).tracksTasmee, isFalse);
    expect(TeacherStudentModel.fromJson({'id': 3}).tracksTasmee, isFalse);
  });

  // The roster is cached on the phone for offline attendance; the sheet
  // opened from it must still offer تسميع.
  test('the cached roster keeps the flag', () {
    const student = TeacherStudentModel(
      id: 3,
      fullName: 'أحمد',
      isActive: true,
      tracksTasmee: true,
    );
    final back = TeacherStudentModel.fromJson(student.toCacheJson());
    expect(back.tracksTasmee, isTrue);
  });

  group('StudentPayloadDto.tracksTasmee', () {
    const base = StudentPayloadDto(
      fullName: 'بلال شرقيني',
      phone: '0550000000',
      address: 'الجزائر العاصمة',
    );

    test('is sent when set, false included', () {
      for (final on in [true, false]) {
        final json = StudentPayloadDto(
          fullName: base.fullName,
          phone: base.phone,
          address: base.address,
          tracksTasmee: on,
        ).toJson();
        expect(json['tracksTasmee'], on);
      }
    });

    test('is omitted when unset, since only an admin may send it', () {
      expect(base.toJson().containsKey('tracksTasmee'), isFalse);
    });
  });
}
