import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/teacher/presentation/pages/notes_page.dart';

void main() {
  test('names the recipients of a note sent to several students', () {
    expect(studentCountLabel(2), 'طالبان');
    expect(studentCountLabel(3), '3 طلاب');
    expect(studentCountLabel(10), '10 طلاب');
    expect(studentCountLabel(11), '11 طالبًا');
    expect(studentCountLabel(25), '25 طالبًا');
    expect(studentCountLabel(103), '103 طلاب');
  });
}
