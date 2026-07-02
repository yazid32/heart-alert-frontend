// lib/screens/chatbot_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/chatbot_service.dart';
import '../services/conversation_manager.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../models/chat_message.dart';

class ChatbotScreen extends StatefulWidget {
  final Map<String, dynamic>? initialContext;
  const ChatbotScreen({super.key, this.initialContext});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ChatbotService _chatbot;
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  Map<String, dynamic>? _currentContext;
  bool _hasError = false;
  String? _errorMessage;
  String? _editingMessageId;
  int _typingSpeed = 0;
  Timer? _typingTimer;
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isListening = false;
  String? _userName;

// lib/screens/chatbot_screen.dart

@override
void initState() {
  super.initState();
  _chatbot = ChatbotService();
  
  // ✅ Load auth token and set it in the service
  _loadAuthToken();
  _debugTokenStatus();
  _loadPersistedMessages();
  _loadUserPreferences();
  _addWelcomeMessage();

  if (widget.initialContext != null) {
    _currentContext = widget.initialContext;
    _chatbot.setContext(_currentContext);
    _addPredictionContext(widget.initialContext!);
  }

  _scrollController.addListener(_onScroll);
}
void _debugTokenStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final token1 = prefs.getString('auth_token');
  final token2 = prefs.getString('access_token');
  final userData = prefs.getString('user');
  
  print('🔍 Debug Token Status:');
  print('  auth_token: ${token1 != null ? token1.substring(0, token1.length > 10 ? 10 : token1.length) : 'null'}');
  print('  access_token: ${token2 != null ? token2.substring(0, token2.length > 10 ? 10 : token2.length) : 'null'}');
  print('  user_data exists: ${userData != null}');
}
Future<void> _loadAuthToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // ✅ Check both possible token keys
    String? token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      // Try the access_token key as fallback
      token = prefs.getString('access_token');
    }
    
    if (token != null && token.isNotEmpty) {
      _chatbot.setAuthToken(token);
      print('✅ Chatbot auth token set');
    } else {
      print('⚠️ No auth token found for chatbot');
    }
  } catch (e) {
    print('❌ Error loading auth token: $e');
  }
}

  @override
  void dispose() {
    _typingTimer?.cancel();
    _savePersistedMessages();
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('chatbot_user_name');
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _saveUserPreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chatbot_$key', value);
    } catch (e) {
      print('Error saving preference: $e');
    }
  }

  Future<void> _loadPersistedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('chat_messages');
      if (saved != null) {
        final List<dynamic> data = jsonDecode(saved);
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((e) => ChatMessage.fromJson(e)).toList());
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _savePersistedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _messages.map((e) => e.toJson()).toList();
      await prefs.setString('chat_messages', jsonEncode(data));
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  void _addWelcomeMessage() {
    if (_messages.isEmpty) {
      final greeting = _getPersonalizedGreeting();
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        text: greeting,
        isUser: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ));
    }
  }

  String _getPersonalizedGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 12) timeGreeting = 'Good morning';
    else if (hour < 17) timeGreeting = 'Good afternoon';
    else timeGreeting = 'Good evening';

    final name = _userName != null ? ' $_userName' : ' Doctor';

    return '''$timeGreeting$name! 👋 I'm HeartBot.

I can help you understand heart disease risk factors, explain medical terms, and support your clinical decisions.

⚕️ **Medical Disclaimer:**
• This is NOT a medical diagnosis.
• Please consult a healthcare professional.
• Information is for educational purposes.
• Clinical judgment should always take precedence.

How can I assist you today?''';
  }

  void _addPredictionContext(Map<String, dynamic> context) {
    final patientName = context['patient_name'] ?? 'Patient';
    final riskScore = (context['risk_score'] as double? ?? 0.0) * 100;
    final riskCategory = context['risk_category'] ?? 'Unknown';
    final hasDisease = context['has_disease'] ?? false;

    final clinicalSummary = '''
**📋 PATIENT CLINICAL SUMMARY**

**Demographics:**
• Name: $patientName
• Age: ${context['age'] ?? '--'} years
• Gender: ${_formatGender(context['gender'])} 

**🫀 Clinical Measurements:**
• Chest Pain Type: ${context['chest_pain_type'] ?? '--'}
• Resting BP: ${context['resting_bp'] ?? '--'} mm Hg
• Cholesterol: ${context['cholesterol'] ?? '--'} mg/dl
• Fasting Blood Sugar: ${context['fasting_blood_sugar'] ?? '--'}
• Resting ECG: ${context['resting_ecg'] ?? '--'}
• Max Heart Rate: ${context['max_heart_rate'] ?? '--'} bpm
• Exercise Angina: ${context['exercise_angina'] ?? '--'}
• ST Depression: ${context['st_depression'] ?? '--'} mm
• ST Slope: ${context['st_slope'] ?? '--'}

**📊 Risk Assessment:**
• Risk Score: ${riskScore.toInt()}%
• Risk Category: ${riskCategory.toUpperCase()}
• Disease Detected: ${hasDisease ? '⚠️ YES' : '✅ NO'}

---
*Ask me about these values, their clinical significance, or treatment recommendations.*
''';

    _messages.add(ChatMessage(
      id: const Uuid().v4(),
      text: clinicalSummary,
      isUser: false,
      timestamp: DateTime.now(),
      isSystem: true,
      isContext: true,
    ));
  }

  String _formatGender(dynamic gender) {
    if (gender == null) return 'Not specified';
    if (gender is int) return gender == 1 ? 'Male' : 'Female';
    return gender.toString();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      await _updateMessage(_editingMessageId!, text);
      return;
    }

    _messageController.clear();
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    _trackEvent('message_sent', {
      'has_context': _currentContext != null,
      'message_length': text.length,
      'message_type': _currentContext != null ? 'contextual' : 'general',
    });

    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(userMessage));
    _scrollToBottom();
    await _savePersistedMessages();

    setState(() {
      _isLoading = true;
    });
    _startTypingTimer();

    try {
      final response = _currentContext != null
          ? await _chatbot.sendMessageWithContext(text, context: _currentContext)
          : await _chatbot.sendMessage(text);

      _typingTimer?.cancel();
      setState(() {
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
        _typingSpeed = 0;
      });

      await _savePersistedMessages();
      _trackEvent('message_received', {'response_length': response.length});
    } catch (e) {
      _typingTimer?.cancel();
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        _typingSpeed = 0;

        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: "❌ I'm sorry, I encountered an error. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }

    _scrollToBottom();
  }

  void _startTypingTimer() {
    _typingSpeed = 0;
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isLoading) {
        setState(() => _typingSpeed++);
      } else {
        timer.cancel();
      }
    });
  }

  void _startListening() async {
    setState(() => _isListening = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Listening... (Tap mic again to stop)'),
        duration: Duration(seconds: 10),
      ),
    );
    
    Future.delayed(const Duration(seconds: 3), () {
      if (_isListening && mounted) {
        setState(() {
          _isListening = false;
          _messageController.text = 'What are the symptoms of heart disease?';
        });
        _sendMessage();
      }
    });
  }

  void _stopListening() {
    setState(() => _isListening = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Stopped listening'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _trackEvent(String event, Map<String, dynamic>? properties) {
    print('📊 Analytics: $event ${properties ?? ''}');
  }

  void _startEditing(String id, String text) {
    setState(() {
      _editingMessageId = id;
      _messageController.text = text;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Future<void> _updateMessage(String id, String newText) async {
    if (newText.trim().isEmpty) return;

    setState(() {
      final index = _messages.indexWhere((m) => m.id == id);
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          text: newText.trim(),
          isUser: _messages[index].isUser,
          timestamp: DateTime.now(),
          isSystem: _messages[index].isSystem,
          isContext: _messages[index].isContext,
          isError: _messages[index].isError,
        );
      }
      _editingMessageId = null;
      _messageController.clear();
    });
    await _savePersistedMessages();
    _scrollToBottom();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Message updated'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _deleteMessage(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.removeWhere((m) => m.id == id);
              });
              _savePersistedMessages();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Message deleted'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleReaction(String messageId, String type) {
    _trackEvent('reaction', {'message_id': messageId, 'type': type});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          type == 'like' 
              ? '👍 Thanks for your feedback!' 
              : '👎 We\'ll improve!',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final show = (maxScroll - currentScroll) > 200;
      if (show != _showScrollToBottom) {
        setState(() => _showScrollToBottom = show);
      }
    }
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = _messages[index];
    final previous = _messages[index - 1];
    final diff = current.timestamp.difference(previous.timestamp);
    return diff.inMinutes > 5;
  }

  List<ChatMessage> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    final query = _searchQuery.toLowerCase();
    return _messages.where((m) => 
      m.text.toLowerCase().contains(query)
    ).toList();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _clearContext() {
    setState(() => _currentContext = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient context cleared. You can now ask general questions.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('This will clear all conversation history. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _chatbot.clearHistory();
                _addWelcomeMessage();
                if (_currentContext != null) {
                  _addPredictionContext(_currentContext!);
                }
                _editingMessageId = null;
                _messageController.clear();
                _searchQuery = '';
                _searchController.clear();
                _isSearching = false;
              });
              _savePersistedMessages();
              _trackEvent('chat_cleared', null);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _copyFullConversation() {
    if (_messages.isEmpty) return;
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('  HEARTBOT CONVERSATION');
    buffer.writeln('  ${DateTime.now().toLocal()}');
    buffer.writeln('═══════════════════════════════════════════════════\n');
    
    for (var message in _messages) {
      if (message.isSystem == true && !message.isUser) continue;
      final prefix = message.isUser ? '👤 Doctor' : '⚕️ HeartBot';
      buffer.writeln('$prefix:');
      buffer.writeln(message.text);
      buffer.writeln('─' * 40);
      buffer.writeln();
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Full conversation copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
    _trackEvent('conversation_copied', {'message_count': _messages.length});
  }

  void _showFullDisclaimer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_information_rounded,
                    color: AppColors.sageGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      '⚠️ Medical Disclaimer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HeartBot is an AI-powered clinical support tool.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• This is NOT a medical diagnosis.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Always consult a qualified healthcare professional.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Information is for educational and reference purposes only.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Clinical judgment should always take precedence.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Verify all information before clinical use.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Never rely solely on AI for medical decisions.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• In emergencies, call emergency services immediately.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const Text(
                    '• Your use of this tool is at your own risk.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ This AI tool is not a substitute for professional medical advice, diagnosis, or treatment.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('I Understand'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<String> _getContextualSuggestions() {
    if (_currentContext != null) {
      final riskScore = (_currentContext!['risk_score'] as double? ?? 0.0) * 100;
      if (riskScore > 50) {
        return [
          'What are the urgent next steps?',
          'Should I refer to a cardiologist?',
          'What medications are typically prescribed?',
          'What are the warning signs to watch for?',
        ];
      }
      return [
        'What lifestyle changes would help?',
        'When should I schedule a follow-up?',
        'Are there any preventive measures?',
        'What tests are recommended?',
      ];
    }
    
    final lastUserMessage = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => _messages.last,
    );
    final text = lastUserMessage.text.toLowerCase();
    
    if (text.contains('symptom') || text.contains('chest')) {
      return [
        'When should I seek emergency care?',
        'What are the common causes?',
        'How can I manage this at home?',
        'What tests are needed?',
      ];
    }
    
    if (text.contains('medication') || text.contains('drug')) {
      return [
        'What are the side effects?',
        'Are there interactions to watch for?',
        'How long should I take this?',
        'What if I miss a dose?',
      ];
    }
    
    return [
      'What is heart disease?',
      'Explain risk factors',
      'How to prevent heart disease?',
      'What are symptoms of heart attack?',
      'Explain cholesterol levels',
    ];
  }

  List<QuickAction> _getQuickActions() {
    if (_currentContext != null) {
      final riskScore = (_currentContext!['risk_score'] as double? ?? 0.0) * 100;
      final color = riskScore > 50 ? Colors.red : Colors.blue;
      return [
        QuickAction(
          icon: Icons.warning_amber_rounded,
          label: 'Urgent Care',
          prompt: 'What urgent steps should I take?',
          color: color,
        ),
        QuickAction(
          icon: Icons.medication_rounded,
          label: 'Treatment',
          prompt: 'What treatment options are appropriate?',
          color: Colors.blue,
        ),
        QuickAction(
          icon: Icons.fitness_center_rounded,
          label: 'Lifestyle',
          prompt: 'What lifestyle changes would help?',
          color: Colors.green,
        ),
        QuickAction(
          icon: Icons.schedule_rounded,
          label: 'Follow-up',
          prompt: 'When should I schedule a follow-up?',
          color: Colors.orange,
        ),
      ];
    }
    
    return [
      QuickAction(
        icon: Icons.favorite_rounded,
        label: 'Heart Health',
        prompt: 'How can I improve heart health?',
        color: Colors.red,
      ),
      QuickAction(
        icon: Icons.warning_rounded,
        label: 'Risk Factors',
        prompt: 'What are the risk factors?',
        color: Colors.orange,
      ),
      QuickAction(
        icon: Icons.medical_services_rounded,
        label: 'Symptoms',
        prompt: 'What are common symptoms?',
        color: Colors.blue,
      ),
      QuickAction(
        icon: Icons.lightbulb_rounded,
        label: 'Prevention',
        prompt: 'How can I prevent heart disease?',
        color: Colors.green,
      ),
    ];
  }

  Widget _buildQuickReplies(Responsive r) {
    if (_isLoading) return const SizedBox.shrink();
    if (_editingMessageId != null) return const SizedBox.shrink();
    if (_isSearching) return const SizedBox.shrink();

    final replies = _getContextualSuggestions();
    final userMessageCount = _messages.where((m) => m.isUser).length;
    if (userMessageCount > 2) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
      height: r.sp(48),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: replies.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: r.wp(8)),
            child: ActionChip(
              label: Text(
                replies[index],
                style: TextStyle(fontSize: r.fs(11), fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _messageController.text = replies[index];
                _sendMessage();
              },
              backgroundColor: AppColors.sageGreen.withOpacity(0.10),
              labelStyle: TextStyle(color: AppColors.sageGreen.withOpacity(0.9)),
              side: BorderSide(
                color: AppColors.sageGreen.withOpacity(0.25),
              ),
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.sp(20)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(Responsive r, AppThemeTokens t) {
    if (_isLoading) return const SizedBox.shrink();
    if (_editingMessageId != null) return const SizedBox.shrink();
    if (_isSearching) return const SizedBox.shrink();

    final actions = _getQuickActions();
    final userMessageCount = _messages.where((m) => m.isUser).length;
    if (userMessageCount < 1) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(4)),
      height: r.sp(40),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return Padding(
            padding: EdgeInsets.only(right: r.wp(6)),
            child: ActionChip(
              avatar: Icon(
                action.icon,
                color: action.color,
                size: r.sp(14),
              ),
              label: Text(
                action.label,
                style: TextStyle(fontSize: r.fs(10)),
              ),
              onPressed: () {
                _messageController.text = action.prompt;
                _sendMessage();
              },
              backgroundColor: action.color.withOpacity(0.08),
              side: BorderSide(
                color: action.color.withOpacity(0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.sp(14)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisclaimerBanner(Responsive r, AppThemeTokens t) {
    return GestureDetector(
      onTap: _showFullDisclaimer,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: r.hp,
          vertical: r.sp(8),
        ),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(
            top: BorderSide(
              color: t.border.withOpacity(0.6),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_information_rounded,
                color: AppColors.sageGreen.withOpacity(0.8),
                size: r.sp(12),
              ),
            ),
            SizedBox(width: r.wp(6)),
            Flexible(
              child: Text(
                'AI-generated, for clinical reference only',
                style: TextStyle(
                  fontSize: r.fs(11),
                  color: t.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: r.wp(6)),
            Text(
              'Details',
              style: TextStyle(
                fontSize: r.fs(10),
                color: AppColors.sageGreen.withOpacity(0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateDefaultName() {
    final firstUserMessage = _messages.firstWhere(
      (m) => m.isUser,
      orElse: () => _messages.last,
    );
    final words = firstUserMessage.text.split(' ');
    if (words.length <= 5) {
      return firstUserMessage.text.length > 30
          ? '${firstUserMessage.text.substring(0, 30)}...'
          : firstUserMessage.text;
    }
    final shortName = '${words.take(5).join(' ')}...';
    return shortName.length > 30 ? '${shortName.substring(0, 30)}...' : shortName;
  }

  void _showExportOptions() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to export')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.text_snippet_rounded),
              title: const Text('Save Conversation'),
              subtitle: const Text('Save with custom name'),
              onTap: () {
                Navigator.pop(context);
                _exportConversation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Export as JSON'),
              subtitle: const Text('Machine-readable format'),
              onTap: () {
                Navigator.pop(context);
                _exportAsJSON();
              },
            ),
            ListTile(
              leading: const Icon(Icons.html_rounded),
              title: const Text('Export as HTML'),
              subtitle: const Text('Beautiful formatted web page'),
              onTap: () {
                Navigator.pop(context);
                _exportAsHTML();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export as PDF'),
              subtitle: const Text('Professional PDF report'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _exportConversation() async {
    final TextEditingController nameController = TextEditingController();
    final String defaultName = _generateDefaultName();

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💾 Save Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give your conversation a name:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Patient Consultation - John Doe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Default: "$defaultName"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '📊 This conversation has ${_messages.where((m) => !(m.isSystem == true && !m.isUser)).length} messages',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    final conversationName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : defaultName;

    try {
      final conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      await ConversationManager.saveConversation(
        conversationId,
        _messages,
        customName: conversationName,
      );

      _trackEvent('conversation_saved', {'name': conversationName});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Conversation saved as "$conversationName"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsJSON() async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'HeartBot_Conversation_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      final jsonData = {
        'exported_at': DateTime.now().toIso8601String(),
        'total_messages': _messages.length,
        'has_context': _currentContext != null,
        'messages': _messages.map((m) => m.toJson()).toList(),
        'context': _currentContext,
      };

      await file.writeAsString(jsonEncode(jsonData));

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HeartBot Conversation JSON Export',
      );

      if (result.status == ShareResultStatus.success) {
        _trackEvent('exported_json', {'message_count': _messages.length});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Conversation exported as JSON'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsHTML() async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'HeartBot_Conversation_${DateTime.now().millisecondsSinceEpoch}.html';
      final file = File('${directory.path}/$fileName');

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>HeartBot Conversation</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: auto; padding: 20px; background: #f5f5f5; }
    .container { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .header { text-align: center; padding: 20px; background: #7A9E7E; color: white; border-radius: 8px; margin-bottom: 20px; }
    .header h1 { margin: 0; font-size: 24px; }
    .header p { margin: 5px 0 0; opacity: 0.9; font-size: 14px; }
    .message { margin: 10px 0; padding: 15px; border-radius: 12px; }
    .user { background: #7A9E7E; color: white; text-align: right; }
    .bot { background: #f0f0f0; color: #333; }
    .time { font-size: 10px; color: #999; margin-top: 5px; }
    .disclaimer { background: #fff3cd; padding: 15px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #ffc107; }
    .disclaimer strong { color: #856404; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>💬 HeartBot Conversation</h1>
      <p>Exported: ${DateTime.now().toLocal()}</p>
    </div>
    <div class="disclaimer">
      <strong>⚠️ Medical Disclaimer:</strong> AI-generated content for clinical reference only. 
      Not a substitute for professional medical advice, diagnosis, or treatment.
    </div>
    ${_messages.where((m) => !(m.isSystem == true && !m.isUser)).map((m) => '''
      <div class="message ${m.isUser ? 'user' : 'bot'}">
        <strong>${m.isUser ? '👤 Doctor' : '⚕️ HeartBot'}</strong>
        <p style="margin: 8px 0;">${m.text.replaceAll('\n', '<br>')}</p>
        <div class="time">${_formatTimeOnly(m.timestamp)}</div>
      </div>
    ''').join('')}
  </div>
</body>
</html>
      ''';

      await file.writeAsString(htmlContent);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HeartBot Conversation HTML Export',
      );

      if (result.status == ShareResultStatus.success) {
        _trackEvent('exported_html', {'message_count': _messages.length});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ HTML exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'HeartBot Conversation',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Exported: ${DateTime.now().toLocal()}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 20),
                ..._messages.where((m) => !(m.isSystem == true && !m.isUser)).map((m) {
                  return pw.Column(
                    crossAxisAlignment: m.isUser 
                        ? pw.CrossAxisAlignment.end 
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        m.isUser ? '👤 Doctor' : '⚕️ HeartBot',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: m.isUser ? PdfColors.blue : PdfColors.green,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                        color: m.isUser 
                            ? PdfColor.fromInt(0x1A0000FF) // Blue with 10% opacity
                            : PdfColor.fromInt(0x1A808080), // Grey with 10% opacity
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          m.text,
                          style: const pw.TextStyle(fontSize: 11, height: 1.5),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                  );
                }).toList(),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text(
                  '⚠️ AI-generated for clinical reference only.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'HeartBot_Conversation_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HeartBot Conversation PDF Export',
      );

      if (result.status == ShareResultStatus.success) {
        _trackEvent('exported_pdf', {'message_count': _messages.length});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('PDF export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
    
  
  void _viewSavedConversations() async {
    try {
      final conversations = await ConversationManager.getConversationList();

      if (conversations.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('💾 Saved Conversations'),
            content: const Text(
              'No saved conversations found.\n\n'
              'Chat with HeartBot and tap the save button to save your conversations.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SavedConversationsSheet(
          conversations: conversations,
          onLoad: _loadConversation,
          onDelete: _deleteConversation,
          onRename: _renameConversation,
        ),
      );
    } catch (e) {
      print('Error loading saved conversations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading conversations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _renameConversation(String id, String newName) async {
    try {
      await ConversationManager.renameConversation(id, newName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Conversation renamed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _viewSavedConversations();
    } catch (e) {
      print('Error renaming conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renaming: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadConversation(String id) async {
    try {
      final messages = await ConversationManager.loadConversation(id);
      if (messages.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _chatbot.clearHistory();
          _editingMessageId = null;
          _messageController.clear();
          _searchQuery = '';
          _searchController.clear();
          _isSearching = false;
        });
        _savePersistedMessages();
        _trackEvent('conversation_loaded', {'message_count': messages.length});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Conversation loaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error loading conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      await ConversationManager.deleteConversation(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Conversation deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      _viewSavedConversations();
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  void _openKnowledgeBase() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _KnowledgeBaseSheet(),
    );
  }

  void _copyLastResponse() {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.lastWhere(
      (msg) => !msg.isUser,
      orElse: () => _messages.last,
    );

    Clipboard.setData(ClipboardData(text: lastMessage.text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Response copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  String _getConversationSummary() {
    final userMessages = _messages.where((m) => m.isUser).length;
    final botMessages = _messages.where((m) => !m.isUser && !(m.isSystem == true)).length;
    final totalMessages = _messages.length;
    
    final topics = <String>[];
    final keywords = ['heart', 'risk', 'cholesterol', 'blood pressure', 'symptom', 'treatment'];
    for (var msg in _messages.where((m) => !m.isUser)) {
      for (var keyword in keywords) {
        if (msg.text.toLowerCase().contains(keyword) && !topics.contains(keyword)) {
          topics.add(keyword);
        }
      }
    }
    
    return '''
📊 Conversation Summary:
• ${userMessages} questions asked
• ${botMessages} responses received
• ${totalMessages} total messages
${topics.isNotEmpty ? '• Topics discussed: ${topics.join(', ')}' : ''}
''';
  }

  void _showConversationStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Conversation Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getConversationSummary(),
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            const Divider(),
            _StatRow(
              label: 'Patient Context',
              value: _currentContext != null ? 'Active' : 'None',
            ),
            _StatRow(
              label: 'Conversation Length',
              value: '${_chatbot.historyLength} exchanges',
            ),
            if (_typingSpeed > 0)
              _StatRow(
                label: 'Avg Response Time',
                value: '${_typingSpeed}s',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimeOnly(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.enter) && 
            !event.isShiftPressed) {
          _sendMessage();
          return KeyEventResult.handled;
        }
        if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
          if (_editingMessageId != null) {
            _cancelEditing();
            return KeyEventResult.handled;
          }
          if (_isSearching) {
            _toggleSearch();
            return KeyEventResult.handled;
          }
        }
        if (event.isKeyPressed(LogicalKeyboardKey.keyC) && 
            event.isControlPressed) {
          _copyLastResponse();
          return KeyEventResult.handled;
        }
        if (event.isKeyPressed(LogicalKeyboardKey.keyF) && 
            event.isControlPressed) {
          _toggleSearch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: _buildAppBar(r, t, isDesktop),
        body: Stack(
          children: [
            _buildBody(r, t, isDesktop),
            if (_showScrollToBottom)
              Positioned(
                bottom: r.sp(120),
                right: r.hp,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sageGreen.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    mini: true,
                    elevation: 0,
                    backgroundColor: AppColors.sageGreen,
                    onPressed: _scrollToBottom,
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Responsive r, AppThemeTokens t, bool isDesktop) {
    final statusDotColor = _currentContext != null
        ? Colors.white
        : (_chatbot.historyLength > 1
            ? const Color(0xFF22C55E)
            : const Color(0xFFFFD27A));

    return AppBar(
      toolbarHeight: isDesktop ? 76 : r.sp(72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: t.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.sageGreen.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: _isSearching
          ? Container(
              height: isDesktop ? 42 : r.sp(40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.85), size: r.sp(18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Container(
                  width: isDesktop ? 40 : r.wp(36),
                  height: isDesktop ? 40 : r.wp(36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isDesktop ? 13 : r.sp(12)),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: isDesktop ? 18 : r.wp(17),
                  ),
                ),
                SizedBox(width: r.wp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'HeartBot',
                        style: TextStyle(
                          fontSize: isDesktop ? 17 : r.fs(16),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusDotColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: statusDotColor.withOpacity(0.6),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _currentContext != null
                                  ? 'Patient context active'
                                  : _chatbot.historyLength > 1
                                      ? 'Active conversation'
                                      : 'Ready to help',
                              style: TextStyle(
                                fontSize: isDesktop ? 11 : r.fs(11),
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _toggleSearch,
            tooltip: 'Close search',
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: _toggleSearch,
            tooltip: 'Search messages (Ctrl+F)',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            tooltip: 'More',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: t.card,
            onSelected: (value) {
              switch (value) {
                case 'stats':
                  _showConversationStats();
                  break;
                case 'knowledge':
                  _openKnowledgeBase();
                  break;
                case 'export':
                  _showExportOptions();
                  break;
                case 'saved':
                  _viewSavedConversations();
                  break;
                case 'copy_all':
                  _copyFullConversation();
                  break;
                case 'clear':
                  _clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'stats',
                enabled: _messages.length > 1,
                child: _MenuRow(icon: Icons.bar_chart_rounded, label: 'Conversation stats'),
              ),
              PopupMenuItem(
                value: 'knowledge',
                child: _MenuRow(icon: Icons.library_books_outlined, label: 'Knowledge base'),
              ),
              PopupMenuItem(
                value: 'export',
                enabled: _messages.length > 1,
                child: _MenuRow(icon: Icons.share_outlined, label: 'Export conversation'),
              ),
              PopupMenuItem(
                value: 'saved',
                child: _MenuRow(icon: Icons.folder_outlined, label: 'Saved conversations'),
              ),
              PopupMenuItem(
                value: 'copy_all',
                enabled: _messages.length > 1,
                child: _MenuRow(icon: Icons.copy_all_rounded, label: 'Copy full conversation'),
              ),
              const PopupMenuDivider(height: 8),
              PopupMenuItem(
                value: 'clear',
                enabled: _messages.length > 1,
                child: _MenuRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Clear chat history',
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
          if (_currentContext != null)
            Padding(
              padding: EdgeInsets.only(right: isDesktop ? 16 : r.wp(8)),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.clear_all,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                onPressed: _clearContext,
                tooltip: 'Clear patient context',
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildBody(Responsive r, AppThemeTokens t, bool isDesktop) {
    return SafeArea(
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: _buildChatContent(r, t),
                    ),
                  ),
                ),
                if (_currentContext != null) ...[
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: t.border.withOpacity(0.5),
                  ),
                  _PatientContextSidebar(
                    contextData: _currentContext!,
                    r: r,
                    t: t,
                  ),
                ],
              ],
            )
          : _buildChatContent(r, t),
    );
  }

  Widget _buildChatContent(Responsive r, AppThemeTokens t) {
    final messages = _isSearching ? _filteredMessages : _messages;

    return Column(
      children: [
        if (_isSearching && _filteredMessages.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(12)),
            color: t.surface,
            child: Center(
              child: Text(
                'No messages found for "$_searchQuery"',
                style: TextStyle(
                  fontSize: r.fs(12),
                  color: t.textMuted,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width >= 900 ? 24 : r.hp,
              vertical: r.sp(16),
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final showTimestamp = _shouldShowTimestamp(index);

              return Column(
                children: [
                  if (showTimestamp)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: r.sp(8)),
                      child: Text(
                        _formatTimeOnly(message.timestamp),
                        style: TextStyle(
                          fontSize: r.fs(10),
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  _ChatBubble(
                    message: message,
                    r: r,
                    isDesktop: MediaQuery.of(context).size.width >= 900,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    onEdit: message.isUser ? () => _startEditing(message.id, message.text) : null,
                    onDelete: () => _deleteMessage(message.id),
                    onReaction: message.isUser ? null : (type) => _handleReaction(message.id, type),
                  ),
                ],
              );
            },
          ),
        ),
        _buildQuickActions(r, t),
        _buildQuickReplies(r),
        if (_hasError && _errorMessage != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
            color: t.dangerBg,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: t.danger,
                  size: r.sp(16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: t.danger,
                      fontSize: r.fs(12),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: r.sp(16), color: t.textMuted),
                  onPressed: () => setState(() => _hasError = false),
                ),
              ],
            ),
          ),
        if (_isLoading) _buildTypingIndicator(r),
        if (_editingMessageId != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
            color: AppColors.sageGreen.withOpacity(t.isDark ? 0.15 : 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  color: AppColors.sageGreen,
                  size: r.sp(16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing message...',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: r.fs(12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _cancelEditing,
                  child: Text('Cancel', style: TextStyle(color: AppColors.sageGreen)),
                ),
              ],
            ),
          ),
        _buildDisclaimerBanner(r, t),
        _buildInputBar(r, t),
      ],
    );
  }

 // In chatbot_screen.dart - Enhanced _buildTypingIndicator

Widget _buildTypingIndicator(Responsive r) {
  final t = AppThemeTokens.of(context);
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width >= 900 ? 24 : r.hp,
      vertical: r.sp(4),
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(20),
          vertical: r.sp(14),
        ),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r.sp(20)),
            topRight: Radius.circular(r.sp(20)),
            bottomRight: Radius.circular(r.sp(20)),
            bottomLeft: Radius.circular(r.sp(4)),
          ),
          border: Border.all(
            color: t.border.withOpacity(0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: t.textPrimary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _AnimatedDot(delay: 0),
                SizedBox(width: r.wp(4)),
                _AnimatedDot(delay: 150),
                SizedBox(width: r.wp(4)),
                _AnimatedDot(delay: 300),
              ],
            ),
            SizedBox(width: r.wp(12)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HeartBot is thinking',
                  style: TextStyle(
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w500,
                    color: t.textMuted,
                  ),
                ),
                if (_typingSpeed > 2)
                  Container(
                    width: 80,
                    height: 2,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: (_typingSpeed > 5) ? 80 : _typingSpeed * 12,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.sageGreen.withOpacity(0.3),
                                AppColors.sageGreen,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Animated Dot Widget

Widget _buildInputBar(Responsive r, AppThemeTokens t) {
  final isDesktop = MediaQuery.of(context).size.width >= 900;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isDesktop ? 24 : r.hp,
      vertical: r.sp(12),
    ),
    decoration: BoxDecoration(
      color: t.surface,
      border: Border(top: BorderSide(color: t.border.withOpacity(0.7))),
      boxShadow: [
        BoxShadow(
          color: t.textPrimary.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(r.sp(28)),
                    border: Border.all(
                      color: _hasError ? Colors.red : t.border,
                      width: _hasError ? 1.4 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: t.textPrimary.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                            fontSize: r.fs(14),
                            color: t.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: _editingMessageId != null
                                ? 'Edit your message...'
                                : _currentContext != null
                                    ? 'Ask about this patient...'
                                    : 'Ask HeartBot anything...',
                            hintStyle: TextStyle(
                              fontSize: r.fs(14),
                              color: t.textMuted,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.wp(20),
                              vertical: r.sp(14),
                            ),
                            prefixIcon: _editingMessageId != null
                                ? Icon(
                                    Icons.edit_rounded,
                                    color: Colors.blue.shade400,
                                    size: r.sp(18),
                                  )
                                : null,
                            suffixIcon: _messageController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: t.textMuted,
                                      size: r.sp(16),
                                    ),
                                    onPressed: _editingMessageId != null
                                        ? _cancelEditing
                                        : () => _messageController.clear(),
                                  )
                                : null,
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          onChanged: (text) => setState(() {}),
                        ),
                      ),
                      // Voice input button (optional)
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening ? Colors.red : t.textMuted,
                          size: r.sp(22),
                        ),
                        onPressed: _isListening ? _stopListening : _startListening,
                        tooltip: 'Voice input',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: r.wp(10)),
              // Animated Send Button
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isDesktop ? 50 : r.wp(52),
                  height: isDesktop ? 50 : r.wp(52),
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.sageGreen,
                              AppColors.sageGreen.withOpacity(0.75),
                            ],
                          ),
                    color: _isLoading ? t.textMuted : null,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sageGreen.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _editingMessageId != null
                        ? Icons.check_rounded
                        : _isLoading
                            ? Icons.stop_rounded
                            : Icons.send_rounded,
                    color: Colors.white,
                    size: isDesktop ? 22 : r.wp(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}}

// ==================== POPUP MENU ROW ====================

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? t.textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? t.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ==================== QUICK ACTION CLASS ====================

class QuickAction {
  final IconData icon;
  final String label;
  final String prompt;
  final Color color;

  QuickAction({
    required this.icon,
    required this.label,
    required this.prompt,
    required this.color,
  });
}

// ==================== STAT ROW ====================

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==================== TYPING DOT ====================

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.sageGreen,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ==================== SAVED CONVERSATIONS SHEET ====================

class _SavedConversationsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final Function(String) onLoad;
  final Function(String) onDelete;
  final Function(String, String) onRename;

  const _SavedConversationsSheet({
    required this.conversations,
    required this.onLoad,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_SavedConversationsSheet> createState() =>
      _SavedConversationsSheetState();
}

class _SavedConversationsSheetState extends State<_SavedConversationsSheet> {
  String _searchQuery = '';
  String _sortBy = 'newest';

  List<Map<String, dynamic>> get _filteredConversations {
    var list = List<Map<String, dynamic>>.from(widget.conversations);

    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final name = c['name'].toString().toLowerCase();
        final preview = c['preview'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || preview.contains(query);
      }).toList();
    }

    switch (_sortBy) {
      case 'newest':
        list.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        break;
      case 'oldest':
        list.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        break;
      case 'name':
        list.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.textMuted.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.sageGreen,
                        AppColors.sageGreen.withOpacity(0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sageGreen.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Conversations',
                        style: TextStyle(
                          fontSize: r.fs(17),
                          fontWeight: FontWeight.w800,
                          color: t.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${_filteredConversations.length} conversation${_filteredConversations.length == 1 ? '' : 's'} saved',
                        style: TextStyle(
                          fontSize: r.fs(12),
                          color: t.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(color: t.textMuted, fontSize: r.fs(13)),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: t.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: t.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18,
                            color: t.textMuted),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              style: TextStyle(color: t.textPrimary, fontSize: r.fs(13)),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                _SortChip(
                  label: 'Newest',
                  selected: _sortBy == 'newest',
                  onTap: () => setState(() => _sortBy = 'newest'),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'Oldest',
                  selected: _sortBy == 'oldest',
                  onTap: () => setState(() => _sortBy = 'oldest'),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'Name',
                  selected: _sortBy == 'name',
                  onTap: () => setState(() => _sortBy = 'name'),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: t.border.withOpacity(0.6)),
          Expanded(
            child: _filteredConversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: t.card,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inbox_outlined,
                            size: 30,
                            color: t.textMuted.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No conversations match your search'
                              : 'No saved conversations yet',
                          style: TextStyle(
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w600,
                            color: t.textMuted,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _searchQuery = ''),
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: _filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _filteredConversations[index];
                      final id = conversation['id'];
                      final name = conversation['name'] ?? 'Unnamed';
                      final preview = conversation['preview'] ?? '';
                      final length = conversation['length'] ?? 0;
                      final hasContext = conversation['hasContext'] ?? false;
                      final timestamp = conversation['timestamp'] ?? '';

                      final date = timestamp.isNotEmpty
                          ? DateTime.parse(timestamp).toLocal()
                          : DateTime.now();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: t.border.withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: t.textPrimary.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onLoad(id),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: hasContext
                                        ? AppColors.sageGreen.withOpacity(0.12)
                                        : t.textMuted.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    hasContext
                                        ? Icons.assignment_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: hasContext
                                        ? AppColors.sageGreen
                                        : t.textMuted,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: r.fs(14),
                                                fontWeight: FontWeight.w700,
                                                color: t.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (hasContext)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.sageGreen
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Patient',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.sageGreen,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (preview.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          preview,
                                          style: TextStyle(
                                            fontSize: r.fs(12),
                                            color: t.textMuted,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: r.fs(10),
                                              color: t.textMuted.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 3,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: t.textMuted.withOpacity(0.4),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$length messages',
                                            style: TextStyle(
                                              fontSize: r.fs(10),
                                              color: t.textMuted.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded,
                                      color: t.textMuted, size: 19),
                                  tooltip: 'Options',
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  color: t.card,
                                  onSelected: (value) {
                                    if (value == 'load') widget.onLoad(id);
                                    if (value == 'rename') {
                                      _showRenameDialog(id, name);
                                    }
                                    if (value == 'delete') {
                                      _confirmDelete(id, name);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'load',
                                      child: _MenuRow(
                                        icon: Icons.download_rounded,
                                        label: 'Load conversation',
                                        color: AppColors.sageGreen,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: _MenuRow(
                                        icon: Icons.edit_outlined,
                                        label: 'Rename',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: _MenuRow(
                                        icon: Icons.delete_outline_rounded,
                                        label: 'Delete',
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String id, String currentName) {
    final TextEditingController controller =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (_) {
            if (controller.text.trim().isNotEmpty) {
              widget.onRename(id, controller.text.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onRename(id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sageGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ==================== SORT CHIP ====================

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageGreen : t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.sageGreen
                : t.border.withOpacity(0.8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : t.textMuted,
          ),
        ),
      ),
    );
  }
}

// ==================== CHAT BUBBLE ====================

// In chatbot_screen.dart - Enhanced _ChatBubble

// In chatbot_screen.dart - Fixed _ChatBubble


class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Responsive r;
  final bool isDesktop;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(String)? onReaction;

  const _ChatBubble({
    required this.message,
    required this.r,
    this.isDesktop = false,
    this.onCopy,
    this.onEdit,
    this.onDelete,
    this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    final isUser = message.isUser;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(context);
                    onCopy?.call();
                  },
                ),
                if (isUser)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(context);
                      onEdit?.call();
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_rounded, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete?.call();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Avatar + Message Row
            Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser) _buildBotAvatar(),
                Flexible(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: r.sp(4),
                      bottom: r.sp(2),
                      left: isUser ? (isDesktop ? 120 : r.wp(48)) : 0,
                      right: isUser ? 0 : (isDesktop ? 120 : r.wp(48)),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: r.wp(18),
                      vertical: r.sp(13),
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.sageGreen,
                                AppColors.sageGreen.withOpacity(0.85),
                              ],
                            )
                          : null,
                      color: isUser
                          ? null
                          : message.isError == true
                              ? Colors.red.shade50
                              : t.card,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(r.sp(20)),
                        topRight: Radius.circular(r.sp(20)),
                        bottomLeft: Radius.circular(isUser ? r.sp(20) : r.sp(6)),
                        bottomRight: Radius.circular(isUser ? r.sp(6) : r.sp(20)),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: message.isError == true
                                  ? Colors.red.shade200
                                  : t.border.withOpacity(0.7),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser ? AppColors.sageGreen : t.textPrimary)
                              .withOpacity(isUser ? 0.2 : 0.06),
                          blurRadius: isUser ? 16 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SelectableText(
                      message.text,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : message.isError == true
                                ? Colors.red.shade700
                                : t.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.6,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Timestamp + Actions
            Padding(
              padding: EdgeInsets.only(
                bottom: r.sp(8),
                left: isUser ? 0 : (isDesktop ? 4 : r.wp(4)),
                right: isUser ? (isDesktop ? 4 : r.wp(4)) : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isSystem == true && !isUser)
                    Icon(
                      Icons.info_outline,
                      size: r.fs(10),
                      color: t.textMuted,
                    ),
                  if (message.isSystem == true && !isUser)
                    SizedBox(width: r.wp(4)),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: r.fs(10),
                      color: t.textMuted.withOpacity(0.7),
                    ),
                  ),
                  if (!isUser && onReaction != null && message.isError != true) ...[
                    SizedBox(width: r.wp(6)),
                    _ReactionButton(
                      icon: Icons.thumb_up_outlined,
                      onTap: () => onReaction?.call('like'),
                      r: r,
                    ),
                    _ReactionButton(
                      icon: Icons.thumb_down_outlined,
                      onTap: () => onReaction?.call('dislike'),
                      r: r,
                    ),
                  ],
                  if (isUser && onEdit != null)
                    _ReactionButton(
                      icon: Icons.edit_outlined,
                      onTap: onEdit!,
                      r: r,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: r.wp(34),
      height: r.wp(34),
      margin: EdgeInsets.only(right: r.wp(8), top: r.sp(4)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.sageGreen,
            AppColors.sageGreen.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.sageGreen.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: r.fs(16),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// Reaction Button Widget
class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Responsive r;

  const _ReactionButton({
    required this.icon,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);
    return IconButton(
      icon: Icon(icon, size: r.sp(14)),
      color: t.textMuted.withOpacity(0.5),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 12,
    );
  }
}
// ==================== KNOWLEDGE BASE SHEET ====================

class _KnowledgeBaseSheet extends StatefulWidget {
  const _KnowledgeBaseSheet({super.key});

  @override
  State<_KnowledgeBaseSheet> createState() => _KnowledgeBaseSheetState();
}

class _KnowledgeBaseSheetState extends State<_KnowledgeBaseSheet> {
  String _searchQuery = '';
  bool _isExpandedAll = false;

  final List<Map<String, dynamic>> _allEntries = [
    {
      'title': 'ECG Interpretation',
      'icon': Icons.favorite_rounded,
      'content': '''
• ST depression ≥ 2mm: Myocardial ischemia (ACC/AHA 2022)
• ST elevation: Acute MI (Class I, Level A)
• T-wave inversion: Ischemia or strain pattern
• Q waves: Previous MI
• PR interval > 200ms: 1st degree AV block
• QTc > 440ms: Prolonged QT interval
''',
      'source': 'ACC/AHA Guidelines 2022',
    },
    {
      'title': 'Cholesterol Guidelines',
      'icon': Icons.bloodtype,
      'content': '''
ESC/EAS 2019 Guidelines:

RISK CATEGORY → LDL TARGET:
• Very High Risk: < 55 mg/dL (Class I, Level A)
• High Risk: < 70 mg/dL (Class I, Level A)
• Moderate Risk: < 100 mg/dL (Class IIa, Level C)
• Low Risk: < 116 mg/dL (Class IIa, Level C)

Total Cholesterol: < 190 mg/dL
''',
      'source': 'ESC/EAS Guidelines 2019',
    },
    {
      'title': 'Blood Pressure Classification',
      'icon': Icons.heart_broken_rounded,
      'content': '''
ESC/ESH 2018 Classification:
• Optimal: < 120/80 mmHg
• Normal: 120-129/80-84 mmHg
• High Normal: 130-139/85-89 mmHg
• Grade 1 HTN: 140-159/90-99 mmHg
• Grade 2 HTN: 160-179/100-109 mmHg
• Grade 3 HTN: ≥ 180/110 mmHg
''',
      'source': 'ESC/ESH Guidelines 2018',
    },
    {
      'title': 'Chest Pain Types',
      'icon': Icons.medical_services_rounded,
      'content': '''
• Type 0 - Typical Angina: Substernal, exertion-related
• Type 1 - Atypical Angina: Atypical features
• Type 2 - Non-anginal: Not cardiac-related
• Type 3 - Asymptomatic: Silent ischemia

For ACS suspicion: ECG within 10 min, Troponin at 0h and 3h
''',
      'source': 'ACC/AHA Guidelines',
    },
    {
      'title': 'Heart Failure Classification',
      'icon': Icons.favorite_rounded,
      'content': '''
NYHA Classification:
• Class I: No limitation
• Class II: Slight limitation
• Class III: Marked limitation
• Class IV: Symptoms at rest

ACC/AHA Stages:
• Stage A: At risk
• Stage B: Structural heart disease
• Stage C: Symptoms
• Stage D: Refractory symptoms
''',
      'source': 'ACC/AHA Guidelines',
    },
    {
      'title': 'Anticoagulation Guidelines',
      'icon': Icons.bloodtype,
      'content': '''
CHA₂DS₂-VASc Score (Atrial Fibrillation):
• Score ≥ 2: OAC recommended
• Score 1: OAC should be considered
• Score 0: No antithrombotic therapy

HAS-BLED Score (Bleeding Risk):
• Score ≥ 3: High bleeding risk
''',
      'source': 'ESC Guidelines 2020',
    },
  ];

  List<Map<String, dynamic>> get _filteredEntries {
    if (_searchQuery.isEmpty) return _allEntries;
    final query = _searchQuery.toLowerCase();
    return _allEntries.where((entry) {
      final title = (entry['title'] as String).toLowerCase();
      final content = (entry['content'] as String).toLowerCase();
      final source = (entry['source'] as String).toLowerCase();
      return title.contains(query) ||
          content.contains(query) ||
          source.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.library_books_rounded,
                    color: AppColors.sageGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Knowledge Base',
                        style: TextStyle(
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        '${_filteredEntries.length} clinical references',
                        style: TextStyle(
                          fontSize: r.fs(12),
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpandedAll
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    color: t.textMuted,
                  ),
                  onPressed: () => setState(() => _isExpandedAll = !_isExpandedAll),
                  tooltip: 'Expand/Collapse all',
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search knowledge base...',
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: t.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: t.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18,
                            color: t.textMuted),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: t.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: r.fs(14),
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _filteredEntries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: t.border.withOpacity(0.5)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _isExpandedAll,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                entry['icon'] as IconData,
                                color: AppColors.sageGreen,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              entry['title'] as String,
                              style: TextStyle(
                                fontSize: r.fs(14),
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              entry['source'] as String,
                              style: TextStyle(
                                fontSize: r.fs(11),
                                color: t.textMuted,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry['content'] as String,
                                      style: TextStyle(
                                        fontSize: r.fs(13),
                                        height: 1.6,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageGreen
                                            .withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.sageGreen
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            color: AppColors.sageGreen,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Source: ${entry['source']}',
                                              style: TextStyle(
                                                fontSize: r.fs(11),
                                                color: t.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== PATIENT CONTEXT SIDEBAR ====================

class _PatientContextSidebar extends StatelessWidget {
  final Map<String, dynamic> contextData;
  final Responsive r;
  final AppThemeTokens t;

  const _PatientContextSidebar({
    required this.contextData,
    required this.r,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final riskScore = ((contextData['risk_score'] ?? 0.0) as double) * 100;
    final riskCategory =
        (contextData['risk_category'] ?? 'unknown').toString().toUpperCase();
    final hasDisease = contextData['has_disease'] == true;

    return Container(
      width: 350,
      color: t.card.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.assignment_ind_rounded,
                    color: AppColors.sageGreen, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Active Patient Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SidebarCard(
                  title: 'Demographics',
                  icon: Icons.person_outline_rounded,
                  t: t,
                  children: [
                    _SidebarRow(
                        label: 'Name',
                        value: '${contextData['patient_name'] ?? 'Patient'}',
                        t: t),
                    _SidebarRow(
                        label: 'Age',
                        value: '${contextData['age'] ?? '--'} years',
                        t: t),
                    _SidebarRow(
                        label: 'Gender',
                        value: '${contextData['gender'] ?? '--'}',
                        t: t),
                  ],
                ),
                const SizedBox(height: 16),
                _SidebarCard(
                  title: 'Risk Assessment',
                  icon: Icons.analytics_outlined,
                  t: t,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Risk Category',
                            style: TextStyle(fontSize: 12, color: t.textMuted)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasDisease
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            riskCategory,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasDisease
                                  ? Colors.red.shade600
                                  : Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Risk Score',
                        style: TextStyle(fontSize: 12, color: t.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: riskScore / 100,
                              backgroundColor: t.border,
                              color: riskScore > 50
                                  ? Colors.red.shade400
                                  : AppColors.sageGreen,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${riskScore.toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SidebarCard(
                  title: 'Vitals & Measurements',
                  icon: Icons.heart_broken_outlined,
                  t: t,
                  children: [
                    _SidebarRow(
                        label: 'Chest Pain Type',
                        value: '${contextData['chest_pain_type'] ?? '--'}',
                        t: t),
                    _SidebarRow(
                        label: 'Resting BP',
                        value: '${contextData['resting_bp'] ?? '--'} mmHg',
                        t: t),
                    _SidebarRow(
                        label: 'Cholesterol',
                        value: '${contextData['cholesterol'] ?? '--'} mg/dl',
                        t: t),
                    _SidebarRow(
                        label: 'Fasting Blood Sugar',
                        value: '${contextData['fasting_blood_sugar'] ?? '--'}',
                        t: t),
                    _SidebarRow(
                        label: 'Resting ECG',
                        value: '${contextData['resting_ecg'] ?? '--'}',
                        t: t),
                    _SidebarRow(
                        label: 'Max Heart Rate',
                        value: '${contextData['max_heart_rate'] ?? '--'} bpm',
                        t: t),
                    _SidebarRow(
                        label: 'Exercise Angina',
                        value: '${contextData['exercise_angina'] ?? '--'}',
                        t: t),
                    _SidebarRow(
                        label: 'ST Depression',
                        value: '${contextData['st_depression'] ?? '--'} mm',
                        t: t),
                    _SidebarRow(
                        label: 'ST Slope',
                        value: '${contextData['st_slope'] ?? '--'}',
                        t: t),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final AppThemeTokens t;

  const _SidebarCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: t.textMuted),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.sageGreen,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeTokens t;

  const _SidebarRow({
    required this.label,
    required this.value,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}