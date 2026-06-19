// lib/services/conversation_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ConversationManager {
  static const String _conversationsKey = 'saved_conversations';

  static Future<void> saveConversation(
    String conversationId,
    List<ChatMessage> messages,
    {String? customName}
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = await _loadAllConversations();
      
      // Generate a name if not provided
      String name = customName ?? _generateConversationName(messages);
      
      // Count actual messages (excluding system messages)
      final realMessages = messages.where((m) => !(m.isSystem == true && !m.isUser)).length;
      
      // Get the last user message for preview
      final lastUserMessage = messages.lastWhere(
        (m) => m.isUser,
        orElse: () => messages.last,
      );
      final preview = lastUserMessage.text.length > 60 
          ? '${lastUserMessage.text.substring(0, 60)}...' 
          : lastUserMessage.text;

      conversations[conversationId] = {
        'name': name,
        'messages': messages.map((m) => m.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'length': realMessages,
        'preview': preview,
        'hasContext': messages.any((m) => m.isContext == true),
      };

      // Limit saved conversations to 50
      if (conversations.length > 50) {
        final sortedKeys = conversations.keys.toList()
          ..sort((a, b) => 
            conversations[a]['timestamp'].compareTo(conversations[b]['timestamp'])
          );
        sortedKeys.removeRange(0, sortedKeys.length - 50);
        conversations.removeWhere((key, _) => !sortedKeys.contains(key));
      }

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

  static Future<List<Map<String, dynamic>>> getConversationList() async {
    try {
      final conversations = await _loadAllConversations();
      final List<Map<String, dynamic>> result = [];
      
      conversations.forEach((id, data) {
        result.add({
          'id': id,
          'name': data['name'] ?? 'Unnamed Conversation',
          'timestamp': data['timestamp'] ?? '',
          'length': data['length'] ?? 0,
          'preview': data['preview'] ?? '',
          'hasContext': data['hasContext'] ?? false,
        });
      });
      
      // Sort by timestamp (newest first)
      result.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      
      return result;
    } catch (e) {
      print('Error loading conversation list: $e');
      return [];
    }
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

  static Future<void> renameConversation(String id, String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversations = await _loadAllConversations();
      if (conversations.containsKey(id)) {
        conversations[id]['name'] = newName;
        await prefs.setString(_conversationsKey, jsonEncode(conversations));
      }
    } catch (e) {
      print('Error renaming conversation: $e');
    }
  }

  static String _generateConversationName(List<ChatMessage> messages) {
    // Find first user message
    final firstUserMessage = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.last,
    );
    
    // Use first few words of the first message
    final words = firstUserMessage.text.split(' ');
    if (words.length <= 5) {
      return firstUserMessage.text;
    }
    return '${words.take(5).join(' ')}...';
  }
}