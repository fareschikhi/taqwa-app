import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/user_model.dart';

void main() {
  test('reads canChat from the manager block', () {
    final user = UserModel.fromJson({
      'id': 1,
      'role': 'MANAGER',
      'manager': {'id': 3, 'canChat': true},
    });

    expect(user.canChat, isTrue);
  });

  test('canChat defaults to false when the API leaves it out', () {
    final user = UserModel.fromJson({
      'id': 1,
      'role': 'MANAGER',
      'manager': {'id': 3},
    });

    expect(user.canChat, isFalse);
  });

  // The cached user is written with toJson and read back with fromJson on
  // the next launch, so a field toJson forgets is lost after a restart.
  test('canChat survives the cache round trip', () {
    final user = UserModel.fromJson({
      'id': 1,
      'role': 'MANAGER',
      'manager': {'id': 3, 'canChat': true},
    });

    expect(UserModel.fromJson(user.toJson()).canChat, isTrue);
  });
}
