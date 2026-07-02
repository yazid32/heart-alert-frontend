import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  // Add to ApiService class
  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
  // Signup
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String licenseNumber,
    required String hospital,
    String? country,
    String? specialty,
    String? phone,
    String? medicalLicensePath,
    String? governmentIdPath,
    required bool termsAccepted,
    String? role,
    String? inviteToken, 
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'license_number': licenseNumber,
        'hospital': hospital,
        'country': country,
        'specialty': specialty,
        'phone': phone,
        'medical_license_path': medicalLicensePath,
        'government_id_path': governmentIdPath,
        'terms_accepted': termsAccepted,
        'role': role, 
        'invite_token': inviteToken,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Signup failed: ${response.body}');
    }
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    print('🌐 Using baseUrl: $baseUrl');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📥 Login response data: $data');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid credentials');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Login error: $e');
      throw Exception(e.toString());
    }
  }
  
  // Get current doctor (requires token)
  static Future<Map<String, dynamic>> getMe(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get doctor info');
    }
  }

  // Check if email already exists
  static Future<bool> checkEmailExists(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-email?email=$email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  // Get prediction history
  static Future<Map<String, dynamic>> getHistory(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get history');
    }
  }

  // Update doctor profile
// In api_service.dart, update the updateProfile method:
static Future<Map<String, dynamic>> updateProfile({
  required String token,
  String? firstName,
  String? lastName,
  String? phone,
  String? hospital,
  String? specialty,
  String? country,  // ADD THIS LINE
}) async {
  final response = await http.put(
    Uri.parse('$baseUrl/me'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: json.encode({
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'hospital': hospital,
      'specialty': specialty,
      'country': country,  // ADD THIS LINE
    }),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to update profile');
  }
}

  // Upload profile picture
  static Future<Map<String, dynamic>> uploadProfilePicture({
    required String token,
    required File imageFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-profile-picture'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Delete profile picture
  static Future<Map<String, dynamic>> deleteProfilePicture({
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/profile-picture'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete profile picture');
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Current password is incorrect');
    } else {
      throw Exception('Failed to change password');
    }
  }

  // Make a prediction
  static Future<Map<String, dynamic>> predict({
    required String token,
    int? patientId,
    String? patientName,
    required int age,
    required int sex,
    required int cp,
    required int trestbps,
    required int chol,
    required int fbs,
    required int restecg,
    required int thalach,
    required int exang,
    required double oldpeak,
    required int slope,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'patient_id': patientId,
        'patient_name': patientName,
        'age': age,
        'sex': sex,
        'cp': cp,
        'trestbps': trestbps,
        'chol': chol,
        'fbs': fbs,
        'restecg': restecg,
        'thalach': thalach,
        'exang': exang,
        'oldpeak': oldpeak,
        'slope': slope,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Prediction failed: ${response.body}');
    }
  }

  // Delete a prediction
  static Future<void> deletePrediction({
    required String token,
    required int predictionId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/prediction/$predictionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete prediction');
    }
  }

  // Get all patients for current doctor
  static Future<Map<String, dynamic>> getPatients({
    required String token,
    String? search,
    int skip = 0,
    int limit = 100,
  }) async {
    String url = '$baseUrl/patients?skip=$skip&limit=$limit';
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get patients: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getAssignedDoctor(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/assistant/doctor'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get assigned doctor');
    }
  }

  // Export prediction as PDF
  static Future<List<int>> exportPredictionPdf({
    required String token,
    required int predictionId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/prediction/$predictionId/export'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to export PDF');
    }
  }

  // Get single patient by ID
  static Future<Map<String, dynamic>> getPatient({
    required String token,
    required int patientId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get patient');
    }
  }

  // Create patient
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

  // Update patient
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

  // Delete patient
  static Future<void> deletePatient({
    required String token,
    required int patientId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/patients/$patientId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete patient');
    }
  }

  // ========== ADMIN ENDPOINTS ==========
  
  static Future<List<dynamic>> getAdminDoctors(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/doctors'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Admin Doctors Response Status: ${response.statusCode}');
      print('📡 Admin Doctors Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
        if (data is Map && data.containsKey('doctors')) {
          return data['doctors'];
        }
        if (data is Map) {
          return [data];
        }
        return [];
      } else {
        print('❌ Failed to get doctors: ${response.statusCode}');
        throw Exception('Failed to get doctors: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting doctors: $e');
      throw Exception('Failed to get doctors: $e');
    }
  }

  static Future<List<dynamic>> getPendingAssistants(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending-assistants'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Pending Assistants Response Status: ${response.statusCode}');
      print('📡 Pending Assistants Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
        if (data is Map && data.containsKey('assistants')) {
          return data['assistants'];
        }
        if (data is Map) {
          return [data];
        }
        return [];
      } else {
        print('❌ Failed to get pending assistants: ${response.statusCode}');
        throw Exception('Failed to get pending assistants: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting pending assistants: $e');
      throw Exception('Failed to get pending assistants: $e');
    }
  }

  static Future<List<dynamic>> getAllAssistants(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/assistants'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 All Assistants Response Status: ${response.statusCode}');
      print('📡 All Assistants Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
        if (data is Map && data.containsKey('assistants')) {
          return data['assistants'];
        }
        return [];
      } else {
        throw Exception('Failed to get assistants');
      }
    } catch (e) {
      print('❌ Error getting assistants: $e');
      throw Exception('Failed to get assistants: $e');
    }
  }

  static Future<Map<String, dynamic>> approveAssistant({
    required String token,
    required int assistantId,
    required int assignedDoctorId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/approve-assistant/$assistantId?assigned_doctor_id=$assignedDoctorId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to approve assistant');
    }
  }

  static Future<Map<String, dynamic>> rejectAssistant({
    required String token,
    required int assistantId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/reject-assistant/$assistantId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to reject assistant');
    }
  }

  static Future<Map<String, dynamic>> removeAssistant({
    required String token,
    required int assistantId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/remove-assistant/$assistantId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to remove assistant');
    }
  }

static Future<Map<String, dynamic>> getMyAssistant(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/doctor/assistant'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    return {"has_assistant": false};
  }
}

  static Future<List<dynamic>> getPendingDoctors(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending-doctors'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        }
        return [];
      } else {
        throw Exception('Failed to get pending doctors');
      }
    } catch (e) {
      print('❌ Error getting pending doctors: $e');
      throw Exception('Failed to get pending doctors: $e');
    }
  }

  static Future<Map<String, dynamic>> approveDoctor({
    required String token,
    required int doctorId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/approve-doctor/$doctorId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to approve doctor');
    }
  }

  static Future<Map<String, dynamic>> rejectDoctor({
    required String token,
    required int doctorId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/reject-doctor/$doctorId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to reject doctor');
    }
  }

  static Future<Map<String, dynamic>> getMyStatus(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-status'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get status: ${response.statusCode}');
  }

  // ========== ASSISTANT REQUEST ENDPOINTS ==========

  // Doctor requests an assistant
  static Future<Map<String, dynamic>> requestAssistant({
    required String token,
    required String assistantEmail,
    required String assistantName,
    String? assistantPhone,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/doctor/request-assistant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'assistant_email': assistantEmail,
        'assistant_name': assistantName,
        'assistant_phone': assistantPhone,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to submit request: ${response.body}');
    }
  }

  // Admin gets all assistant requests
  static Future<List<dynamic>> getAssistantRequests(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/assistant-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : [];
      } else {
        throw Exception('Failed to get requests');
      }
    } catch (e) {
      print('❌ Error getting requests: $e');
      return [];
    }
  }

  // Admin approves request
  static Future<Map<String, dynamic>> approveRequest({
    required String token,
    required int requestId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/approve-request/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to approve request');
    }
  }

  // Admin rejects request
  static Future<Map<String, dynamic>> rejectRequest({
    required String token,
    required int requestId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/reject-request/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to reject request');
    }
  }

  // Get single doctor details (admin only)
static Future<Map<String, dynamic>> getDoctorDetails({
  required String token,
  required int doctorId,
}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/admin/doctor/$doctorId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to get doctor details');
  }
}

static Future<Map<String, dynamic>> verifyPhone(String phoneNumber) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-phone'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone_number': phoneNumber}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {'valid': true, 'message': 'Verification service unavailable'};
    }
  } catch (e) {
    print('Phone verification error: $e');
    return {'valid': true, 'message': 'Could not verify phone number'};
  }
}

// Add these methods to ApiService class in api_service.dart

static Future<Map<String, dynamic>> sendVerificationEmail(String email) async {
  print('📧 API call: Sending verification email to $email');
  
  final response = await http.post(
    Uri.parse('$baseUrl/send-verification-email'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'email': email}),
  );
  
  print('📡 Response status: ${response.statusCode}');
  print('📡 Response body: ${response.body}');
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to send verification email: ${response.body}');
  }
}

// Verify email with token
static Future<Map<String, dynamic>> verifyEmail(String token) async {
  final response = await http.post(
    Uri.parse('$baseUrl/verify-email'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'token': token}),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to verify email');
  }
}

// Check if email is verified
static Future<bool> isEmailVerified(String email) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/check-email-verified?email=$email'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['verified'] == true;
    }
    return false;
  } catch (e) {
    print('Error checking email verification: $e');
    return false;
  }
}

// Check if doctor has a pending request
static Future<Map<String, dynamic>> getDoctorPendingRequest(String token) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/doctor/pending-request'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'has_pending': false};
  } catch (e) {
    print('Error checking pending request: $e');
    return {'has_pending': false};
  }
}

// Cancel a pending assistant request
static Future<Map<String, dynamic>> cancelAssistantRequest({
  required String token,
  required int requestId,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/doctor/cancel-request/$requestId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to cancel request');
  }
}

// ========== DOCTOR REMOVE ASSISTANT ==========
static Future<Map<String, dynamic>> doctorRemoveAssistant(String token) async {
  final response = await http.delete(
    Uri.parse('$baseUrl/doctor/remove-assistant'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to remove assistant');
  }
  
}

// ========== ADMIN STATS ==========
static Future<Map<String, dynamic>> getAdminStats(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/admin/stats'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to get stats');
  }
}
// ========== SUPPORT TICKETS ==========

static Future<Map<String, dynamic>> createSupportTicket({
  required String name,
  required String email,
  required String subject,
  required String message,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/support/create'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    }),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to send message');
  }
}

static Future<List<dynamic>> getAdminTickets(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/admin/tickets'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to get tickets');
  }
}

static Future<Map<String, dynamic>> replyToTicket(
  String token,
  int ticketId,
  String message,
  String status,
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/admin/tickets/$ticketId/reply'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: json.encode({
      'message': message,
      'status': status,
    }),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to send reply');
  }
}

static Future<Map<String, dynamic>> updateTicketStatus(
  String token,
  int ticketId,
  String status,
) async {
  final response = await http.put(
    Uri.parse('$baseUrl/admin/tickets/$ticketId/status'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: json.encode({'status': status}),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to update status');
  }
}


// ========== SUBSCRIPTION API ==========

static Future<List<dynamic>> getPricingPlans() async {
  final response = await http.get(
    Uri.parse('$baseUrl/pricing-plans'),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to get pricing plans');
  }
}

static Future<Map<String, dynamic>> createCheckoutSession({
  required String token,
  required String planName,
  required String successUrl,
  required String cancelUrl,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/create-checkout-session'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: json.encode({
      'plan_name': planName,
      'success_url': successUrl,
      'cancel_url': cancelUrl,
    }),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to create checkout session');
  }
}

static Future<Map<String, dynamic>> getMySubscription(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/my-subscription'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to get subscription');
  }
}


static Future<Map<String, dynamic>> removeHospitalDoctor({
  required String token,
  required int doctorId,
}) async {
  final response = await http.delete(
    Uri.parse('$baseUrl/hospital/remove-doctor/$doctorId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to remove doctor');
  }
}

// hospital part
// Add to api_service.dart
static Future<List<Map<String, dynamic>>> getHospitalDoctors(String token) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital/doctors'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      return [];  // ← Return empty list instead of throwing error
    }
  } catch (e) {
    return [];  // ← Return empty list on any error
  }
}

static Future<List<Map<String, dynamic>>> getPendingInvitations(String token) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital/pending-invitations'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      return [];  // ← Return empty list
    }
  } catch (e) {
    return [];  // ← Return empty list
  }
}

static Future<void> inviteDoctorToHospital({
  required String token,
  required String email,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/hospital/invite-doctor'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': email,
    }),
  );
  
  if (response.statusCode != 201 && response.statusCode != 200) {
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? error['message'] ?? 'Failed to invite doctor');
  }
}

static Future<void> resendInvitation(String token, String invitationId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/hospital/resend-invitation'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'invitation_id': invitationId}),
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to resend invitation');
  }
}

static Future<void> cancelInvitation(String token, String invitationId) async {
  final response = await http.delete(
    Uri.parse('$baseUrl/hospital/cancel-invitation/$invitationId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode != 200) {
    throw Exception('Failed to cancel invitation');
  }
}

// Add to api_service.dart
static Future<Map<String, dynamic>> getHospitalStats(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/hospital/stats'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    return {
      'total_doctors': 0,
      'total_patients': 0,
      'total_predictions': 0,
      'total_assistants': 0,
      'active_doctors': 0,
    };
  }
}
// Accept invitation for logged-in user
// Accept invitation for logged-in user (like email verification)
static Future<Map<String, dynamic>> acceptInvitation(String token, String inviteToken) async {
  final response = await http.post(
    Uri.parse('$baseUrl/accept-invitation'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'invite_token': inviteToken}),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to accept invitation');
  }
}
// Cancel subscription
static Future<Map<String, dynamic>> cancelSubscription(String token) async {
  final response = await http.post(
    Uri.parse('$baseUrl/cancel-subscription'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to cancel subscription');
  }
}


}