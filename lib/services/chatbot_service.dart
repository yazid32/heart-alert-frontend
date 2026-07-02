// lib/services/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../config/app_config.dart';

class ChatbotService {
  // ==================== CONFIGURATION ====================
  static String get _baseUrl => AppConfig.baseUrl;
  static const int _maxHistoryLength = 20;

  // ==================== STATE MANAGEMENT ====================
  final List<Map<String, String>> _history = [];
  bool _isProcessing = false;
  int _requestCount = 0;
  String? _authToken;
  Map<String, dynamic>? _currentContext;
  bool _tokenChecked = false;

  ChatbotService() {
    _resetHistory();
    // ✅ Auto-load token on initialization
    _loadTokenFromStorage();
  }

  // ==================== PUBLIC METHODS ====================

  /// Initialize with auth token
  void setAuthToken(String token) {
    _authToken = token;
    _tokenChecked = true;
    print('✅ Chatbot auth token set: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
  }

  /// Set current patient context
  void setContext(Map<String, dynamic>? context) {
    _currentContext = context;
  }

  /// Send a message to the chatbot
  Future<String> sendMessage(String message) async {
    if (_isProcessing) {
      return 'Please wait for the previous response to complete.';
    }
    
    // ✅ Check token and try to reload if missing
    if (!await _ensureToken()) {
      return '🔒 Please login to use the chatbot.';
    }

    return _sendToAPI(message);
  }
    Future<void> _loadTokenFromStorage() async {
    if (_tokenChecked) return; // ✅ Only check once
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try auth_token first, then access_token
      String? token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        token = prefs.getString('access_token');
      }
      
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        _tokenChecked = true;
        print('✅ Chatbot loaded token from storage');
        print('🔑 Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
      } else {
        print('⚠️ No token found in storage');
        _tokenChecked = true;
      }
    } catch (e) {
      print('❌ Error loading token from storage: $e');
      _tokenChecked = true;
    }
  }
  Future<bool> _ensureToken() async {
      // If we already have a token, use it
      if (_authToken != null && _authToken!.isNotEmpty) {
        return true;
      }
      
      // ✅ Try to load token from storage
      await _loadTokenFromStorage();
      
      if (_authToken != null && _authToken!.isNotEmpty) {
        return true;
      }
      
      print('⚠️ No auth token available for chatbot');
      return false;
  }
  /// Send a message with patient context
  Future<String> sendMessageWithContext(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    if (_isProcessing) {
      return 'Please wait for the previous response to complete.';
    }

    if (!await _ensureToken()) {
      return '🔒 Please login to use the chatbot.';
    }

    if (context != null) {
      _currentContext = context;
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
    _isProcessing = false;
  }


  Future<String> _sendToAPI(String message) async {
    // Add user message to history
    _history.add({'role': 'user', 'content': message});
    _trimHistory();

    _isProcessing = true;
    _requestCount++;

    try {
      print('📤 Sending chat request #$_requestCount to backend...');
      print('🔑 Token: ${_authToken?.substring(0, _authToken!.length > 10 ? 10 : _authToken!.length)}...');

      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'message': message,
          'context': _currentContext,
          'history': _history.where((m) => m['role'] != 'system').toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _handleSuccess(response);
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        print('⚠️ Token expired, clearing and asking to re-login');
        await _clearToken();
        return '🔒 Your session has expired. Please login again.';
      } else if (response.statusCode == 429) {
        return '⏱️ Too many requests. Please wait a moment and try again.';
      } else if (response.statusCode == 503) {
        return '🔧 The chatbot service is temporarily unavailable. Please try again later.';
      } else {
        return _handleError(response);
      }
    } catch (e) {
      print('❌ Chat exception: $e');
      return _handleException(e);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _clearToken() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('access_token');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  String _handleSuccess(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      final reply = data['response'] as String?;
      if (reply == null || reply.trim().isEmpty) {
        return 'I received an empty response. Please try again.';
      }

      _history.add({'role': 'assistant', 'content': reply});
      _trimHistory();

      return reply;
    } catch (e) {
      print('❌ Error parsing response: $e');
      return 'Error processing the response. Please try again.';
    }
  }

  String _handleError(http.Response response) {
    try {
      final error = jsonDecode(response.body);
      final detail = error['detail'] ?? 'Unknown error';
      return '❌ Error: $detail';
    } catch (e) {
      return 'An unexpected error occurred (${response.statusCode}). Please try again.';
    }
  }

  String _handleException(dynamic e) {
    if (e.toString().contains('SocketException')) {
      return '📡 Network error: Unable to connect to the server. Please check your internet connection.';
    } else if (e.toString().contains('TimeoutException')) {
      return '⏱️ Request timed out. The server is taking too long to respond. Please try again.';
    } else {
      return '❌ Error: ${e.toString()}';
    }
  }

  void _trimHistory() {
    if (_history.length > _maxHistoryLength) {
      final recentMessages = _history.sublist(_history.length - _maxHistoryLength);
      _history.clear();
      _history.addAll(recentMessages);
    }
  }
}