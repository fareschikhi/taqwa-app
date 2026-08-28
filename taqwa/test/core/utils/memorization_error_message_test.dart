import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/memorization_error_message.dart';

void main() {
  final request = RequestOptions(path: '/memorization');

  DioException withBody(Object? body, {int status = 400}) => DioException(
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );

  group('memorizationErrorMessage', () {
    test('blames attendance only when the server says so', () {
      final error = withBody({
        'statusCode': 400,
        'code': 'STUDENT_ABSENT',
        'message': 'Cannot record memorization for a student marked absent',
      });

      expect(memorizationErrorMessage(error), contains('كغائب'));
    });

    // The bug this guards: any 400 used to read as "student is absent", so a
    // rejected amount sent the teacher to the attendance chips, where nothing
    // was wrong and nothing they did could help.
    test('does not blame attendance for an unrelated 400', () {
      final error = withBody({
        'statusCode': 400,
        'message':
            'SMALLREVISION is recorded in HIZBS, so amountDone must be at most 60',
      });

      expect(memorizationErrorMessage(error), isNot(contains('كغائب')));
    });

    test('does not blame attendance for a server fault', () {
      final error = withBody({'message': 'Internal error'}, status: 500);

      expect(memorizationErrorMessage(error), isNot(contains('كغائب')));
    });

    test('keeps the interceptor wording when the request never landed', () {
      final error = DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
        error: 'تعذّر الاتصال بالخادم، يرجى التحقق من الشبكة',
      );

      expect(memorizationErrorMessage(error), contains('تعذّر الاتصال'));
    });

    test('falls back to a generic failure for a non-Dio error', () {
      expect(memorizationErrorMessage(StateError('boom')), 'فشل حفظ التسميع');
    });
  });
}
