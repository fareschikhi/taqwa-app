import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';

void main() {
  group('StudentPayloadDto', () {
    const payload = StudentPayloadDto(
      fullName: 'Bilal Cherguini',
      phone: '4008',
      birthDate: '2012-05-01',
      address: 'الجزائر العاصمة',
      halaqaId: 2,
      parentId: 5,
      avatar: 'https://example.test/a.png',
    );

    test('never puts a password on the wire', () {
      // A student is a record, not an account. Creating one must not be able
      // to mint a login, so the key must be absent even when every optional
      // field is filled in.
      expect(payload.toJson().containsKey('password'), isFalse);
    });

    test('sends the fields the backend still accepts', () {
      // The backend's CreateStudentDto has no 'role' field — it derives the
      // role from isAdult — and its ValidationPipe strips unknown keys
      // anyway, so a hardcoded 'role' here would just be a lie the moment
      // this same DTO can describe an adult student too.
      expect(payload.toJson(), {
        'fullName': 'Bilal Cherguini',
        'phone': '4008',
        'birthDate': '2012-05-01',
        'address': 'الجزائر العاصمة',
        'halaqaId': 2,
        'avatar': 'https://example.test/a.png',
        'isAdult': false,
        'parentId': 5,
      });
    });

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

    test('sends tracksHadith when set', () {
      final json = const StudentPayloadDto(
        fullName: 'بلال شرقيني',
        phone: '0550000000',
        birthDate: '1998-01-01',
        address: 'الجزائر العاصمة',
        tracksHadith: true,
      ).toJson();

      expect(json['tracksHadith'], true);
    });

    test('omits tracksHadith when unset, since only an admin may send it', () {
      final json = const StudentPayloadDto(
        fullName: 'بلال شرقيني',
        phone: '0550000000',
        birthDate: '1998-01-01',
        address: 'الجزائر العاصمة',
      ).toJson();

      expect(json.containsKey('tracksHadith'), isFalse);
    });
  });
}
