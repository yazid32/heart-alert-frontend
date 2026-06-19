import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  static final String _apiKey = dotenv.env['CHATBOT_API_KEY'] ?? '';
  static const String _model = 'openrouter/free';
  
  static const String _systemPrompt = 
      'You are HeartBot, an AI clinical assistant specialized in cardiology and heart disease. '
      'You help doctors understand heart disease risk factors, interpret medical terms, '
      'and support clinical decisions. Always be concise, accurate, and professional. '
      'Remind users to rely on their own clinical judgment and not treat your responses as final medical advice.';

  // Keeps conversation history for multi-turn chat
  final List<Map<String, String>> _history = [];

  ChatbotService() {
    _history.add({'role': 'system', 'content': _systemPrompt});
  }

  // For normal messages
  Future<String> sendMessage(String message) async {
    return _sendToAPI(message);
  }

  // For messages with patient context
  Future<String> sendMessageWithContext(String message, {Map<String, dynamic>? context}) async {
    if (context != null) {
      final patientName = context['patient_name'] ?? 'Patient';
      final riskScore = (context['risk_score'] as double) * 100;
      final riskCategory = context['risk_category'];
      final age = context['age'];
      final gender = context['gender'] ?? 'Not specified';
      
      // Extract all clinical parameters
      final chestPainType = context['chest_pain_type'] ?? 'Not specified';
      final restingBP = context['resting_bp'] ?? 'Not specified';
      final cholesterol = context['cholesterol'] ?? 'Not specified';
      final fastingBloodSugar = context['fasting_blood_sugar'] ?? 'Not specified';
      final restingECG = context['resting_ecg'] ?? 'Not specified';
      final maxHeartRate = context['max_heart_rate'] ?? 'Not specified';
      final exerciseAngina = context['exercise_angina'] ?? 'Not specified';
      final stDepression = context['st_depression'] ?? 'Not specified';
      final stSlope = context['st_slope'] ?? 'Not specified';
      
      final contextualMessage = '''
PATIENT CASE:
- Name: $patientName
- Age: $age
- Gender: $gender
- Risk Score: ${riskScore.toInt()}% ($riskCategory)

CLINICAL PARAMETERS:
- Chest Pain Type: $chestPainType
- Resting Blood Pressure: $restingBP mm Hg
- Cholesterol: $cholesterol mg/dl
- Fasting Blood Sugar: $fastingBloodSugar
- Resting ECG: $restingECG
- Max Heart Rate: $maxHeartRate bpm
- Exercise Angina: $exerciseAngina
- ST Depression: $stDepression mm
- ST Slope: $stSlope

DOCTOR'S QUESTION: $message

Please provide medical insights based on this patient's data. Be professional and helpful.
''';
      return _sendToAPI(contextualMessage);
    } else {
      return _sendToAPI(message);
    }
  }

  Future<String> _sendToAPI(String message) async {
  _history.add({'role': 'user', 'content': message});

  try {
    print('📤 Sending to OpenRouter...');
    
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'HTTP-Referer': 'https://heartalert.app',
        'X-Title': 'HeartBot',
      },
      body: jsonEncode({
        'model': _model,
        'messages': _history,
        'max_tokens': 500,
      }),
    ).timeout(const Duration(seconds: 30));

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['choices'][0]['message']['content'] as String;
      _history.add({'role': 'assistant', 'content': reply});
      return reply;
    } else if (response.statusCode == 401) {
      return "API Key invalid. Please check your OpenRouter API key.";
    } else if (response.statusCode == 402) {
      return "API quota exceeded. Please try again later.";
    } else {
      final error = jsonDecode(response.body);
      return "API Error: ${error['error']?['message'] ?? 'Unknown error'}";
    }
  } catch (e) {
    print('❌ Chatbot exception: $e');
    return "Network error: ${e.toString()}";
  }
}
  Future<String> _fallbackAPI(String message) async {
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-7b-instruct:free',
          'messages': [{'role': 'user', 'content': message}],
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        return "I'm sorry, I'm having trouble connecting. Please try again in a moment.";
      }
    } catch (e) {
      return "Service temporarily unavailable. Please try again later.";
    }
  }

  void clearHistory() {
    _history.clear();
    _history.add({'role': 'system', 'content': _systemPrompt});
  }
}