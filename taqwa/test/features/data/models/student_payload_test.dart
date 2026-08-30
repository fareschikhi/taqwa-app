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
  });
}
