import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/auth_response_model.dart';
import 'package:taqwa/features/data/models/user_model.dart';

void main() {
  group('AuthResponseModel', () {
    // The login response carries the manager privilege flags that decide what
    // an admin may do. AuthUser dropped them, so the model must parse into
    // UserModel instead.
    test('keeps manager privileges from the login response', () {
      final model = AuthResponseModel.fromJson({
        'accessToken': 'token-123',
        'user': {
          'id': 2,
          'fullName': 'Abdelkader Meziane',
          'phone': '1001',
          'role': 'MANAGER',
          'isActive': true,
          'manager': {
            'id': 1,
            'canManageAccounts': true,
            'canDeleteAccounts': false,
          },
        },
      });

      expect(model.accessToken, 'token-123');
      expect(model.user, isA<UserModel>());
      expect(model.user.role, UserRole.manager);
      expect(model.user.managerId, 1);
      expect(model.user.canManageAccounts, isTrue);
      expect(model.user.canDeleteAccounts, isFalse);
    });
  });
}
