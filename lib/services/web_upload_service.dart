// lib/services/web_upload_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add this import
import '../config/app_config.dart';

class WebUploadService {
  static Future<String> uploadDocument({
    required String fileName,
    required List<int> bytes,
    String? token, 
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/upload-document'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Explicitly parse the mime type for web
      String extension = fileName.split('.').last.toLowerCase();
      String mimeType = 'application/octet-stream';

      if (extension == 'png') mimeType = 'image/png';
      if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
      if (extension == 'pdf') mimeType = 'application/pdf';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType), // This is required for Flutter Web
        ),
      );

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = json.decode(responseData.body);
        return data['file_path']; 
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${responseData.body}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }
}