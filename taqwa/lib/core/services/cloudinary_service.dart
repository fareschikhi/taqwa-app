import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'REDACTED_CLOUDINARY_CLOUD_NAME';
  static const String apiKey = 'REDACTED_CLOUDINARY_API_KEY';
  static const String apiSecret = 'REDACTED_CLOUDINARY_API_SECRET';

  static final Dio _dio = Dio();

  /// Uploads an image to Cloudinary and returns the secure URL
  static Future<String> uploadImage(XFile file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Generate SHA-1 signature for Cloudinary signed upload
    final toSign = 'timestamp=$timestamp$apiSecret';
    final bytes = utf8.encode(toSign);
    final signature = sha1.convert(bytes).toString();

    final fileName = file.name.isNotEmpty ? file.name : 'avatar.jpg';
    final fileBytes = await file.readAsBytes();

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'api_key': apiKey,
      'timestamp': timestamp.toString(),
      'signature': signature,
    });

    final response = await _dio.post(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      final url = response.data['secure_url'] as String?;
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    throw Exception('فشل رفع الصورة إلى Cloudinary');
  }
}
