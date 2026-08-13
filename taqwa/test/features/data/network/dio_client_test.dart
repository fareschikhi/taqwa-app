import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

void main() {
  // The API runs on Render's free plan, which stops an idle service and only
  // starts it again on the next request. Measured cold starts against
  // taqwa-api-txbq.onrender.com took 51.4s and 54.3s, while a warm request
  // answers in ~1.3s. The connection itself is established in ~80ms either
  // way, so it is the *response* that is slow, not the network.
  //
  // If the client gives up before the container finishes booting, the first
  // login after any quiet period fails with a connection error that blames
  // the user's network. These bounds keep that from regressing.
  const measuredColdStart = Duration(seconds: 55);

  group('DioClient timeouts', () {
    test('receiveTimeout outlasts a measured Render cold start', () {
      final receiveTimeout = DioClient.instance.options.receiveTimeout;

      expect(receiveTimeout, isNotNull);
      expect(
        receiveTimeout! > measuredColdStart,
        isTrue,
        reason:
            'receiveTimeout is $receiveTimeout, shorter than the $measuredColdStart '
            'cold start measured against the deployed API. The first login after '
            'the service idles would fail.',
      );
    });

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
