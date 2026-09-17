import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/session_expiry.dart';

DioException _failure({int? statusCode, DioExceptionType? type}) {
  final options = RequestOptions(path: '/users/me');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode),
  );
}

void main() {
  test('reads a 401 as the stored token being rejected', () {
    expect(isRejectedSession(_failure(statusCode: 401)), isTrue);
  });

  test('does not treat an unreachable server as a rejected token', () {
    // Signing the user out because their bus went through a tunnel would lose
    // them the cached screens they can still read offline.
    expect(
      isRejectedSession(_failure(type: DioExceptionType.connectionError)),
      isFalse,
    );
  });

  test('does not treat a server fault as a rejected token', () {
    expect(isRejectedSession(_failure(statusCode: 500)), isFalse);
  });

  test('does not treat a 403 as a rejected token', () {
    // The token is good; this user is simply not allowed at that endpoint.
    expect(isRejectedSession(_failure(statusCode: 403)), isFalse);
  });

  test('does not treat a plain error as a rejected token', () {
    expect(isRejectedSession(FormatException('bad json')), isFalse);
  });
}
