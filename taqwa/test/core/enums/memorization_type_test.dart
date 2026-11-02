import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/enums/memorization_type.dart';

void main() {
  group('MemorizationTypeX.fromApi', () {
    test('parses every value apiValue can produce', () {
      for (final type in MemorizationType.values) {
        expect(MemorizationTypeX.fromApi(type.apiValue), type);
      }
    });

    test('returns null for null or unrecognised values', () {
      // Read screens take this straight off untyped JSON, so a missing or
      // unexpected type must not throw at them.
      expect(MemorizationTypeX.fromApi(null), isNull);
      expect(MemorizationTypeX.fromApi(''), isNull);
      expect(MemorizationTypeX.fromApi('REVISION'), isNull);
    });
  });
}
