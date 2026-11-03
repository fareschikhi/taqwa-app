import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';

import '../../../helpers/stub_api.dart';

void main() {
  late StubApi api;
  final repo = PointsRepository();

  setUp(() => api = StubApi.install((_) => (200, {})));

  group('adjust', () {
    // 0.1 + 0.2 is 0.30000000000000004 as a double; the server allows two
    // decimals and would refuse it.
    test('rounds the amount to two decimals before sending', () async {
      await repo.adjust(userId: 70, amount: 0.1 + 0.2);
      expect(api.sent('POST', '/points').single.data, {
        'userId': 70,
        'amount': 0.3,
      });
    });

    test('keeps the sign and the reason', () async {
      await repo.adjust(userId: 70, amount: -1.5, reason: 'سلوك');
      expect(api.sent('POST', '/points').single.data, {
        'userId': 70,
        'amount': -1.5,
        'reason': 'سلوك',
      });
    });

    test('leaves a blank reason out', () async {
      await repo.adjust(userId: 70, amount: 2, reason: '  ');
      expect(
        (api.sent('POST', '/points').single.data as Map).containsKey('reason'),
        isFalse,
      );
    });
  });

  test('remove deletes one entry by id', () async {
    await repo.remove(9);
    expect(api.sent('DELETE', '/points/9'), hasLength(1));
  });
}
