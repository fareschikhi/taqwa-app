import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/constants/hadith_books.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';

void main() {
  group('parseHadithBooks', () {
    test('keeps list order and drops names that are not on the list', () {
      expect(
        parseHadithBooks([kHadithBooks[4], 'صحيح البخاري', kHadithBooks[0]]),
        [kHadithBooks[0], kHadithBooks[4]],
      );
    });

    test('an empty list means no hadith, whatever the flag says', () {
      expect(parseHadithBooks([], tracksHadith: true), isEmpty);
    });

    // A roster cached on the phone before the list existed only has the old
    // flag; hadith was all-or-nothing then, so the student keeps every book.
    test('falls back to every book for a legacy flag-only payload', () {
      expect(parseHadithBooks(null, tracksHadith: true), kHadithBooks);
      expect(parseHadithBooks(null), isEmpty);
    });
  });

  test('both student models read the nested and flat shapes', () {
    final admin = StudentModel.fromJson({
      'id': 3,
      'user': {'fullName': 'أحمد'},
      'hadithBooks': [kHadithBooks[2]],
    });
    expect(admin.hadithBooks, [kHadithBooks[2]]);
    expect(admin.tracksHadith, isTrue);

    final teacher = TeacherStudentModel.fromJson({
      'id': 3,
      'fullName': 'أحمد',
      'tracksHadith': true,
    });
    expect(teacher.hadithBooks, kHadithBooks);
  });
}
