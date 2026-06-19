// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool? isSystem;
  final bool? isContext;
  final bool? isError;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSystem,
    this.isContext,
    this.isError,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'isSystem': isSystem,
    'isContext': isContext,
    'isError': isError,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    isSystem: json['isSystem'],
    isContext: json['isContext'],
    isError: json['isError'],
  );
}