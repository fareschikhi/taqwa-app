import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/manager_model.dart';

void main() {
  // GET /managers returns the assignment join rows, each wrapping the halaqa
  // itself: [{managerId, halaqaId, assignedAt, halaqa: {id, name, level}}].
  // The admin form needs those ids to pre-tick the toggles when editing.
  test('ManagerModel unwraps the halaqa out of each join row', () {
    final manager = ManagerModel.fromJson({
      'id': 1,
      'user': {'id': 2, 'fullName': 'عبد القادر مزيان'},
      'halaqas': [
        {
          'managerId': 1,
          'halaqaId': 1,
          'halaqa': {'id': 1, 'name': 'حلقة الفرقان', 'level': 'مبتدئ'},
        },
        {
          'managerId': 1,
          'halaqaId': 4,
          'halaqa': {'id': 4, 'name': 'حلقة النور', 'level': 'متوسط'},
        },
      ],
    });

    expect(manager.halaqasCount, 2);
    expect(manager.firstHalaqaName, 'حلقة الفرقان');
    expect(manager.halaqas!.map((h) => h['id']).toList(), [1, 4]);
  });

  test('ManagerModel copes with a manager that has no halaqas', () {
    final manager = ManagerModel.fromJson({
      'id': 2,
      'user': {'id': 3, 'fullName': 'خالد رحماني'},
      'halaqas': <dynamic>[],
    });

    expect(manager.halaqasCount, 0);
    expect(manager.firstHalaqaName, 'غير معين');
  });

  test('ManagerModel copes with halaqas missing entirely', () {
    final manager = ManagerModel.fromJson({
      'id': 3,
      'user': {'id': 4, 'fullName': 'مدير'},
    });

    expect(manager.halaqas, isNull);
    expect(manager.halaqasCount, 0);
    expect(manager.firstHalaqaName, 'غير معين');
  });
}
