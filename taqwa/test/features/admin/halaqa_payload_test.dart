import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/pages/create_halaqa_page.dart';

void main() {
  group('buildHalaqaPayload', () {
    test('an edit payload never carries studentIds', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        description: 'وصف',
        studentIds: const [1, 2, 3],
        isEditing: true,
      );

      // The update endpoint replaces the whole roster with whatever it is
      // sent, so the key must be absent rather than merely empty.
      expect(data.containsKey('studentIds'), isFalse);
      expect(data['name'], 'حلقة النور');
      expect(data['teacherId'], 7);
      expect(data['description'], 'وصف');
    });

    test('a create payload carries the picked students', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        description: '',
        studentIds: const [1, 2, 3],
        isEditing: false,
      );

      expect(data['studentIds'], const [1, 2, 3]);
      expect(data.containsKey('description'), isFalse);
    });

    test('a create payload with no picked students omits studentIds', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        description: '',
        studentIds: const [],
        isEditing: false,
      );

      expect(data.containsKey('studentIds'), isFalse);
    });
  });
}
