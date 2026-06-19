import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/app_config.dart';
class PatientService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<Map<String, dynamic>> createPatient({
    required String token,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? medicalHistory,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/patients'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'medical_history': medicalHistory,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create patient');
    }
  }

  static Future<List<dynamic>> getPatients({
    required String token,
    String? search,
    int skip = 0,
    int limit = 50,
  }) async {
    String url = '$baseUrl/patients?skip=$skip&limit=$limit';
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['patients'];
    } else {
      throw Exception('Failed to get patients');
    }
  }

  static Future<Map<String, dynamic>> updatePatient({
    required String token,
    required int patientId,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? medicalHistory,
    String? notes,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'medical_history': medicalHistory,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update patient');
    }
  }


  static Future<void> deletePatient({
    required String token,
    required int patientId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete patient');
    }
  }

  static String formatDateOfBirth(DateTime? date) {
    if (date == null) return 'Not set';
    return DateFormat('MMM d, yyyy').format(date);
  }
static int calculateAge(String? dateOfBirth) {
  if (dateOfBirth == null || dateOfBirth.isEmpty) return 0;
  try {
    final dob = DateTime.parse(dateOfBirth);
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  } catch (e) {
    return 0;
  }
}
}