// lib/services/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'medical_knowledge_base.dart';
import 'medical_prompt_engineer.dart';
import 'medical_validator.dart';
import 'multilingual_service.dart';
import '../models/chat_message.dart'; // Only if needed

class ChatbotService {
  // ==================== CONFIGURATION ====================
  static String get _apiKey {
    final key = dotenv.env['CHATBOT_API_KEY'];
    if (key == null || key.isEmpty) {
      print('⚠️ WARNING: CHATBOT_API_KEY not set in .env file');
    }
    return key ?? '';
  }

  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const int _maxTokens = 500;
  static const int _timeoutSeconds = 30;
  static const int _maxHistoryLength = 20;

  // ==================== SERVICES ====================
  final MedicalKnowledgeBase _knowledgeBase = MedicalKnowledgeBase();
  final MedicalPromptEngineer _promptEngineer = MedicalPromptEngineer();
  final MedicalValidator _validator = MedicalValidator();
  final MultilingualService _multilingualService = MultilingualService();

  // ==================== STATE MANAGEMENT ====================
  final List<Map<String, String>> _history = [];
  bool _isProcessing = false;
  int _requestCount = 0;

  ChatbotService() {
    _resetHistory();
  }

  // ==================== PUBLIC METHODS ====================

  /// Send a message to the chatbot
  Future<String> sendMessage(String message) async {
    if (_isProcessing) {
      return 'Please wait for the previous response to complete.';
    }
    return _sendToAPI(message);
  }

  /// Send a message with patient context
  Future<String> sendMessageWithContext(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    if (_isProcessing) {
      return 'Please wait for the previous response to complete.';
    }

    if (context != null) {
      final contextualMessage = _buildContextualPrompt(message, context);
      return _sendToAPI(contextualMessage);
    }
    return _sendToAPI(message);
  }

  /// Clear conversation history
  void clearHistory() {
    _resetHistory();
  }

  /// Get current history length
  int get historyLength => _history.length;

  /// Get conversation summary
  String getConversationSummary() {
    final userMessages = _history
        .where((msg) => msg['role'] == 'user')
        .map((msg) => msg['content'])
        .toList();
    
    if (userMessages.isEmpty) return 'No conversation yet.';
    return 'Conversation has ${userMessages.length} exchanges.';
  }

  // ==================== PRIVATE METHODS ====================

  void _resetHistory() {
    _history.clear();
    _history.add({'role': 'system', 'content': _promptEngineer.getSystemPrompt()});
    _isProcessing = false;
  }

  String _buildContextualPrompt(String message, Map<String, dynamic> context) {
    // 1. Extract patient data
    final patientName = context['patient_name'] ?? 'Patient';
    final riskScore = (context['risk_score'] as double? ?? 0.0) * 100;
    final riskCategory = context['risk_category'] ?? 'Unknown';
    final age = context['age'] ?? 'Not specified';
    final gender = _formatGender(context['gender']);

    // 2. Build clinical parameters
    final clinicalParams = <String>[];
    final paramMap = {
      'Chest Pain Type': context['chest_pain_type'],
      'Resting Blood Pressure': context['resting_bp'],
      'Cholesterol': context['cholesterol'],
      'Fasting Blood Sugar': context['fasting_blood_sugar'],
      'Resting ECG': context['resting_ecg'],
      'Max Heart Rate': context['max_heart_rate'],
      'Exercise Angina': context['exercise_angina'],
      'ST Depression': context['st_depression'],
      'ST Slope': context['st_slope'],
    };

    paramMap.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        clinicalParams.add('- $key: $value');
      }
    });

    // 3. Search knowledge base for relevant information
    final knowledge = _knowledgeBase.searchKnowledge(message);

    // 4. Build the final prompt
    return '''
PATIENT CASE:
- Name: $patientName
- Age: $age
- Gender: $gender
- Risk Score: ${riskScore.toInt()}%
- Risk Category: $riskCategory

CLINICAL PARAMETERS:
${clinicalParams.join('\n')}

${knowledge != null ? 'MEDICAL KNOWLEDGE REFERENCE:\n$knowledge\n' : ''}

DOCTOR'S QUESTION: $message

Please provide professional medical insights based on this patient data. Be concise, accurate, and evidence-based.
''';
  }

  String _formatGender(dynamic gender) {
    if (gender == null) return 'Not specified';
    if (gender is int) return gender == 1 ? 'Male' : 'Female';
    return gender.toString();
  }

  Future<String> _sendToAPI(String message) async {
    // Validate API key
    if (_apiKey.isEmpty) {
      return 'Chatbot service is not configured. Please set the API key.';
    }

    // Add user message to history
    _history.add({'role': 'user', 'content': message});
    _trimHistory();

    _isProcessing = true;
    _requestCount++;

    try {
      print('📤 Sending request #$_requestCount to OpenRouter...');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _buildHeaders(),
        body: jsonEncode(_buildRequestBody()),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _handleSuccess(response);
      } else if (response.statusCode == 401) {
        return '🔒 API authentication failed. Please check your OpenRouter API key configuration.';
      } else if (response.statusCode == 402) {
        return '⚠️ API quota exceeded. Please try again later or contact support.';
      } else if (response.statusCode >= 500) {
        return '🔧 The AI service is temporarily unavailable. Please try again in a few moments.';
      } else {
        return _handleOtherError(response);
      }
    } catch (e) {
      print('❌ Chatbot exception: $e');
      return _handleException(e);
    } finally {
      _isProcessing = false;
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'HTTP-Referer': 'https://heartalert.app',
      'X-Title': 'HeartBot',
      'Accept': 'application/json',
    };
  }

  Map<String, dynamic> _buildRequestBody() {
    return {
      'model': 'openrouter/free',
      'messages': _history,
      'max_tokens': _maxTokens,
      'temperature': 0.7,
      'top_p': 0.9,
      'stream': false,
    };
  }

  String _handleSuccess(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      // Validate response structure
      if (data['choices'] == null || data['choices'].isEmpty) {
        return 'Received an unexpected response format. Please try again.';
      }

      final reply = data['choices'][0]['message']['content'] as String;
      
      // Validate reply is not empty
      if (reply.trim().isEmpty) {
        return 'I received an empty response. Please try again.';
      }

      // Validate and sanitize the response
      final validatedReply = _validator.validateAndSanitize(reply);

      // Add assistant response to history
      _history.add({'role': 'assistant', 'content': validatedReply});
      _trimHistory();

      return validatedReply;
    } catch (e) {
      print('❌ Error parsing response: $e');
      return 'Error processing the response. Please try again.';
    }
  }

  String _handleOtherError(http.Response response) {
    try {
      final error = jsonDecode(response.body);
      final message = error['error']?['message'] ?? 'Unknown error';
      return 'Error: $message';
    } catch (e) {
      return 'An unexpected error occurred (${response.statusCode}). Please try again.';
    }
  }

  String _handleException(dynamic e) {
    if (e.toString().contains('SocketException')) {
      return '📡 Network error: Unable to connect to the AI service. Please check your internet connection.';
    } else if (e.toString().contains('TimeoutException')) {
      return '⏱️ Request timed out. The AI service is taking too long to respond. Please try again.';
    } else {
      return '❌ Error: ${e.toString()}';
    }
  }

  void _trimHistory() {
    // Keep system prompt + last N messages
    if (_history.length > _maxHistoryLength) {
      final systemPrompt = _history.first;
      final recentMessages = _history.sublist(_history.length - _maxHistoryLength + 1);
      _history.clear();
      _history.add(systemPrompt);
      _history.addAll(recentMessages);
    }
  }
}