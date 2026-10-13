import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

void main() {
  group('DioClient timeouts', () {
    test('connectTimeout allows for a slow mobile network', () {
      final connectTimeout = DioClient.instance.options.connectTimeout;

      expect(connectTimeout, isNotNull);
      expect(
        connectTimeout! >= const Duration(seconds: 30),
        isTrue,
        reason: 'connectTimeout is $connectTimeout, too short for a weak mobile signal.',
      );
    });
  });
}
