import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/pages/create_halaqa_page.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';

HalaqaModel _halaqa(int id, String name, int teacherId) =>
    HalaqaModel(id: id, name: name, teacherId: teacherId);

void main() {
  // The school runs one halaqa per teacher as the norm. Handing a teacher a
  // second one is allowed, but the admin has to mean it — so this decides
  // when the confirmation is owed, and names what she already runs.
  group('otherHalaqasOf', () {
    final fajr = _halaqa(1, 'حلقة الفجر', 7);
    final noor = _halaqa(2, 'حلقة النور', 7);
    final huda = _halaqa(3, 'حلقة الهدى', 9);

    test('a free teacher on a new halaqa needs no confirmation', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 9,
        currentTeacherId: null,
        editingHalaqaId: null,
        allHalaqas: [fajr, noor],
      );

      expect(result, isEmpty);
    });

    test('a teacher who already runs one names it on a new halaqa', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 9,
        currentTeacherId: null,
        editingHalaqaId: null,
        allHalaqas: [fajr, huda],
      );

      expect(result, ['حلقة الهدى']);
    });

    test('a teacher who already runs several names them all', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 7,
        currentTeacherId: null,
        editingHalaqaId: null,
        allHalaqas: [fajr, noor, huda],
      );

      expect(result, ['حلقة الفجر', 'حلقة النور']);
    });

    // Renaming a halaqa or editing its fees leaves the teacher exactly where
    // she was. Counting the halaqa she is already on would nag on every save.
    test(
      'keeping the same teacher on her own halaqa needs no confirmation',
      () {
        final result = otherHalaqasOf(
          selectedTeacherId: 7,
          currentTeacherId: 7,
          editingHalaqaId: 1,
          allHalaqas: [fajr, huda],
        );

        expect(result, isEmpty);
      },
    );

    // She is over the norm already, but this save is not what put her there,
    // so it is not this dialog's business to raise it.
    test('keeping a teacher who already runs several stays silent', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 7,
        currentTeacherId: 7,
        editingHalaqaId: 1,
        allHalaqas: [fajr, noor, huda],
      );

      expect(result, isEmpty);
    });

    test('handing a halaqa to a teacher who runs another names it', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 7,
        currentTeacherId: 9,
        editingHalaqaId: 3,
        allHalaqas: [fajr, huda],
      );

      expect(result, ['حلقة الفجر']);
    });

    test('handing a halaqa to a free teacher needs no confirmation', () {
      final result = otherHalaqasOf(
        selectedTeacherId: 9,
        currentTeacherId: 7,
        editingHalaqaId: 1,
        allHalaqas: [fajr],
      );

      expect(result, isEmpty);
    });

    // The halaqa under edit is hers only because of the row being replaced,
    // so it must never be counted as evidence of a second halaqa.
    test(
      'the halaqa being edited never counts against its own new teacher',
      () {
        final result = otherHalaqasOf(
          selectedTeacherId: 7,
          currentTeacherId: 9,
          editingHalaqaId: 1,
          allHalaqas: [_halaqa(1, 'حلقة الفجر', 7)],
        );

        expect(result, isEmpty);
      },
    );

    // The submit guard rejects an empty picker before this runs; returning
    // empty rather than throwing keeps a stray call a no-op.
    test('no teacher picked yields nothing to confirm', () {
      final result = otherHalaqasOf(
        selectedTeacherId: null,
        currentTeacherId: null,
        editingHalaqaId: null,
        allHalaqas: [fajr, noor],
      );

      expect(result, isEmpty);
    });
  });
}
