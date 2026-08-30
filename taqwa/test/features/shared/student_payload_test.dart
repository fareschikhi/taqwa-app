import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';

void main() {
  group('StudentPayloadDto.toJson', () {
    test('carries a password for an adult student', () {
      final json = const StudentPayloadDto(
        fullName: 'بلال شرقيني',
        phone: '0550000000',
        birthDate: '1998-01-01',
        address: 'الجزائر العاصمة',
        isAdult: true,
        password: 'secret123',
      ).toJson();

      expect(json['isAdult'], true);
      expect(json['password'], 'secret123');
    });

    // An adult student is his own guardian by construction, so a parent on
    // his record would be dead data the backend never reads.
    test('omits parentId for an adult student even if one was picked', () {
      final json = const StudentPayloadDto(
        fullName: 'بلال شرقيني',
        phone: '0550000000',
        birthDate: '1998-01-01',
        address: 'الجزائر العاصمة',
        isAdult: true,
        password: 'secret123',
        parentId: 4,
      ).toJson();

      expect(json.containsKey('parentId'), isFalse);
    });

    test('keeps parentId and carries no password for a normal student', () {
      final json = const StudentPayloadDto(
        fullName: 'محمد أمين',
        phone: '0660000000',
        birthDate: '2012-05-01',
        address: 'وهران',
        parentId: 4,
      ).toJson();

      expect(json['isAdult'], false);
      expect(json['parentId'], 4);
      expect(json.containsKey('password'), isFalse);
    });

    // The backend's CreateStudentDto has no 'role' field and strips unknown
    // keys anyway, but once the same DTO can describe an adult student a
    // hardcoded 'role': 'STUDENT' becomes an outright lie rather than dead
    // weight.
    test('no longer sends a hardcoded role', () {
      final json = const StudentPayloadDto(
        fullName: 'محمد أمين',
        phone: '0660000000',
        birthDate: '2012-05-01',
        address: 'وهران',
      ).toJson();

      expect(json.containsKey('role'), isFalse);
    });
  });
}
