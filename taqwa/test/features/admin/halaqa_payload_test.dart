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

    test('carries the fine rates for an adults halaqa', () {
      final data = buildHalaqaPayload(
        name: 'حلقة الكبار',
        teacherId: 1,
        level: '',
        studentIds: const [],
        isEditing: false,
        isAdult: true,
        absenceFee: 50,
        lateFee: 20,
        missedMemorizationFee: 30,
      );

      expect(data['isAdult'], true);
      expect(data['absenceFee'], 50);
      expect(data['lateFee'], 20);
      expect(data['missedMemorizationFee'], 30);
    });

    // A rate of 0 is a real setting — a halaqa that fines absence but not
    // lateness — so it must survive the payload rather than being treated
    // as "no value".
    test('keeps a zero rate for an adults halaqa', () {
      final data = buildHalaqaPayload(
        name: 'حلقة الكبار',
        teacherId: 1,
        level: '',
        studentIds: const [],
        isEditing: false,
        isAdult: true,
        absenceFee: 50,
        lateFee: 0,
        missedMemorizationFee: 30,
      );

      expect(data.containsKey('lateFee'), isTrue);
      expect(data['lateFee'], 0);
    });

    // Rates on a children's halaqa would be dead data the backend ignores and
    // a future reader would have to explain.
    test('omits the rates for a normal halaqa', () {
      final data = buildHalaqaPayload(
        name: 'حلقة النور',
        teacherId: 1,
        level: '',
        studentIds: const [],
        isEditing: false,
      );

      expect(data['isAdult'], false);
      expect(data.containsKey('absenceFee'), isFalse);
      expect(data.containsKey('lateFee'), isFalse);
      expect(data.containsKey('missedMemorizationFee'), isFalse);
    });
  });
}
