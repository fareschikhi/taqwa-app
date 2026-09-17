import 'package:dio/dio.dart';

/// Whether [error] means the stored token itself was refused, as opposed to
/// the request never reaching a server that could judge it.
///
/// The distinction decides whether a failed launch signs the user out. Only a
/// 401 says the token is spent; a timeout, a dead socket or a 500 say nothing
/// about it, and treating those as an expiry would sign people out every time
/// the network dips.
bool isRejectedSession(Object error) =>
    error is DioException && error.response?.statusCode == 401;
