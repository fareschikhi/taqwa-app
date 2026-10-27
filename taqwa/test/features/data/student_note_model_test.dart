import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/student_note_model.dart';

Map<String, dynamic> _recipient(int id, String name) => {
  'studentId': id,
  'student': {
    'user': {'fullName': name},
  },
};

void main() {
  group('StudentNoteModel recipients', () {
    test('a note to all students is one bulk note', () {
      final note = StudentNoteModel.fromJson({
        'id': 1,
        'teacherId': 2,
        'note': 'غداً مراجعة',
        'createdAt': '2026-10-27T10:00:00.000Z',
        'studentId': 7,
        'student': _recipient(7, 'Bilal')['student'],
        'recipients': [_recipient(7, 'Bilal'), _recipient(8, 'Yusuf')],
      });
      expect(note.isBulk, isTrue);
      expect(note.recipientIds, [7, 8]);
      expect(note.studentName, 'Bilal');
    });

    test('a note to one student is not bulk', () {
      final note = StudentNoteModel.fromJson({
        'id': 1,
        'studentId': 7,
        'recipients': [_recipient(7, 'Bilal')],
      });
      expect(note.isBulk, isFalse);
    });

    test('a response without recipients still parses', () {
      final note = StudentNoteModel.fromJson({'id': 1, 'studentId': 7});
      expect(note.recipientIds, isEmpty);
      expect(note.isBulk, isFalse);
    });
  });
}
