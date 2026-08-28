import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/pages/create_halaqa_page.dart';

void main() {
  group('buildHalaqaPayload', () {
    test('an edit payload never carries studentIds', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: 'متوسط',
        studentIds: const [1, 2, 3],
        isEditing: true,
      );

      // The update endpoint replaces the whole roster with whatever it is
      // sent, so the key must be absent rather than merely empty.
      expect(data.containsKey('studentIds'), isFalse);
      expect(data['name'], 'حلقة النور');
      expect(data['teacherId'], 7);
      expect(data['level'], 'متوسط');
    });

    test('a create payload carries the picked students', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: '',
        studentIds: const [1, 2, 3],
        isEditing: false,
      );

      expect(data['studentIds'], const [1, 2, 3]);
    });

    test('a create payload with no picked students omits studentIds', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: '',
        studentIds: const [],
        isEditing: false,
      );

      expect(data.containsKey('studentIds'), isFalse);
    });

    test('a create payload carries the level', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: 'مبتدئ',
        studentIds: const [],
        isEditing: false,
      );

      expect(data['level'], 'مبتدئ');
    });

    test('a create payload with a blank level omits the key', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: '',
        studentIds: const [],
        isEditing: false,
      );

      // Leaving the field untouched must not write an empty string over the
      // column's NULL default.
      expect(data.containsKey('level'), isFalse);
    });

    test('an edit payload with a blank level sends null to clear it', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 7,
        level: '',
        studentIds: const [],
        isEditing: true,
      );

      // Omitting the key would leave the old level in place forever, so an
      // emptied field has to travel as an explicit null.
      expect(data.containsKey('level'), isTrue);
      expect(data['level'], isNull);
    });
  });
}
