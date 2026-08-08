import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';

/// Uploads images through our own API rather than straight to Cloudinary.
///
/// The backend holds the Cloudinary credentials and signs the upload, so no
/// secret ships inside the app. Going through [DioClient] also means the
/// request carries the caller's bearer token, and the API decides whether
/// their role is allowed to upload at all.
class ImageUploadService {
  ImageUploadService._();

  /// Uploads [file] and returns the hosted URL to store on the user record.
  ///
  /// Throws an [Exception] carrying a user-facing Arabic message on failure.
  static Future<String> uploadImage(XFile file) async {
    final fileName = file.name.isNotEmpty ? file.name : 'avatar.jpg';
    final fileBytes = await file.readAsBytes();

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    try {
      final response = await DioClient.instance.post(
        '${ApiEndpoints.uploads}/image',
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          // Photos take longer than the 10s default the client is tuned to.
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final url = response.data?['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return url;
      }
      throw Exception('فشل رفع الصورة');
    } on DioException catch (e) {
      // ErrorInterceptor has already turned this into an Arabic message.
      throw Exception(e.error?.toString() ?? 'فشل رفع الصورة');
    }
  }
}
