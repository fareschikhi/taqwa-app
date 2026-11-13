import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqwa/core/utils/halaqa_order.dart';

/// A group as a screen holds it: a halaqa id, null for the unassigned bucket.
typedef G = ({int? id, String name});

List<String> names(List<G> groups) => groups.map((g) => g.name).toList();

void main() {
  const a = (id: 1, name: 'أ');
  const b = (id: 2, name: 'ب');
  const c = (id: 3, name: 'ج');
  const none = (id: null, name: 'غير مسجلين');

  group('applyHalaqaOrder', () {
    List<G> apply(List<G> groups, List<int> order) =>
        applyHalaqaOrder<G>(groups, order, idOf: (g) => g.id);

    test('leaves the list alone with no saved order', () {
      expect(names(apply([a, b, c, none], [])), ['أ', 'ب', 'ج', 'غير مسجلين']);
    });

    test('puts saved halaqas first, in the saved order', () {
      expect(names(apply([a, b, c], [3, 1])), ['ج', 'أ', 'ب']);
    });

    test('keeps unsaved halaqas in their incoming order after the saved', () {
      expect(names(apply([c, a, b], [2])), ['ب', 'ج', 'أ']);
    });

    test('keeps the unassigned bucket last even if it arrived first', () {
      expect(names(apply([none, a, b], [2])), ['ب', 'أ', 'غير مسجلين']);
    });

    test('ignores saved ids that are not on screen', () {
      expect(names(apply([a, b], [99, 2])), ['ب', 'أ']);
    });
  });

  group('mergeHalaqaOrder', () {
    test('a first save is just the new order', () {
      expect(mergeHalaqaOrder([], [5, 2, 9]), [5, 2, 9]);
    });

    test('a subset reorder keeps the hidden halaqas in their slots', () {
      // A manager who sees only 2 and 4 swaps them; 1 and 3 do not move.
      expect(mergeHalaqaOrder([1, 2, 3, 4], [4, 2]), [1, 4, 3, 2]);
    });

    test('a full reorder replaces the saved order', () {
      expect(mergeHalaqaOrder([1, 2, 3], [3, 1, 2]), [3, 1, 2]);
    });

    test('a halaqa new to the saved order joins it', () {
      expect(mergeHalaqaOrder([1, 2], [7, 1]), [7, 2, 1]);
    });
  });

  group('HalaqaOrderStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('reads back what was written for the same user', () async {
      await HalaqaOrderStore.write(10, [3, 1, 2]);

      expect(await HalaqaOrderStore.read(10), [3, 1, 2]);
    });

    test('keeps each account on the phone apart', () async {
      await HalaqaOrderStore.write(10, [3, 1]);
      await HalaqaOrderStore.write(11, [1, 3]);

      expect(await HalaqaOrderStore.read(10), [3, 1]);
      expect(await HalaqaOrderStore.read(11), [1, 3]);
    });

    test('reads an empty order when nothing was saved', () async {
      expect(await HalaqaOrderStore.read(10), isEmpty);
    });
  });
}
