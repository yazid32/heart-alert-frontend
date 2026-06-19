import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class FileUploadService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<String> uploadDocument(File file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload-document'),
    );

    String extension = file.path.split('.').last.toLowerCase();
    String mimeType = 'application/octet-stream';

    if (extension == 'png') mimeType = 'image/png';
    if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
    if (extension == 'pdf') mimeType = 'application/pdf';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonResponse['file_path'];
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }
}