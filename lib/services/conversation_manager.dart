// lib/services/conversation_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ConversationManager {
  static const String _conversationsKey = 'saved_conversations';

  static Future<void> saveConversation(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = await _loadAllConversations();
      
      conversations[conversationId] = {
        'messages': messages.map((m) => m.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'length': messages.length,
      };

      await prefs.setString(_conversationsKey, jsonEncode(conversations));
    } catch (e) {
      print('Error saving conversation: $e');
    }
  }

  static Future<Map<String, dynamic>> _loadAllConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_conversationsKey);
      if (data != null) {
        return jsonDecode(data);
      }
    } catch (e) {
      print('Error loading conversations: $e');
    }
    return {};
  }

  static Future<List<ChatMessage>> loadConversation(String id) async {
    try {
      final conversations = await _loadAllConversations();
      final data = conversations[id];
      if (data != null) {
        final messages = data['messages'] as List;
        return messages
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading conversation: $e');
    }
    return [];
  }

  static Future<void> deleteConversation(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = await _loadAllConversations();
      conversations.remove(id);
      await prefs.setString(_conversationsKey, jsonEncode(conversations));
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  static Future<List<String>> getConversationList() async {
    final conversations = await _loadAllConversations();
    return conversations.keys.toList();
  }
}