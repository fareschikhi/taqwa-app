import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/storage/secure_storage.dart';

void main() {
  test('clears a damaged keystore instead of failing every read', () {
    expect(appSecureStorage.aOptions.toMap()['resetOnError'], 'true');
  });
}
