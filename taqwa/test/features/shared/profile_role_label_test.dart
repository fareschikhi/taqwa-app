import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/shared/presentation/pages/profile_page.dart';

/// The profile screen used to hard-code one person's details and label every
/// role it did not recognise as "ولي أمر". It now reads the signed-in user, so
/// every role it can be opened by needs a label and an initial of its own.
void main() {
  group('roleLabelFor', () {
    test('names each role that can reach the profile', () {
      expect(roleLabelFor(UserRole.admin), 'مدير النظام');
      expect(roleLabelFor(UserRole.manager), 'مشرف');
      expect(roleLabelFor(UserRole.teacher), 'معلم');
      expect(roleLabelFor(UserRole.parent), 'ولي أمر');
      expect(roleLabelFor(UserRole.student), 'طالب');
      expect(roleLabelFor(UserRole.adultStudent), 'طالب بالغ');
    });

    test('does not fall back to parent for a manager', () {
      // The bug this replaces: manager fell through to the parent default.
      expect(roleLabelFor(UserRole.manager), isNot(roleLabelFor(UserRole.parent)));
    });
  });

  group('initialFor', () {
    test('uses the first letter of the name', () {
      expect(initialFor('Ahmed Boudiaf'), 'A');
      expect(initialFor('أحمد بوضياف'), 'أ');
    });

    test('falls back rather than crashing on an empty name', () {
      expect(initialFor(''), '؟');
      expect(initialFor('   '), '؟');
    });
  });

  group('canEditProfile', () {
    test('only an admin may change profile details', () {
      expect(canEditProfile(UserRole.admin), isTrue);
      expect(canEditProfile(UserRole.manager), isFalse);
      expect(canEditProfile(UserRole.teacher), isFalse);
      expect(canEditProfile(UserRole.parent), isFalse);
      expect(canEditProfile(UserRole.student), isFalse);
    });
  });
}
