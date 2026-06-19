// lib/screens/chatbot_screen.dart
import 'dart:convert';
import 'dart:async'; // ADD THIS LINE
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
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

  // ==================== LIFECYCLE ====================

  @override
  void initState() {
    super.initState();
    _chatbot = ChatbotService();
    _loadPersistedMessages();
    _addWelcomeMessage();

    if (widget.initialContext != null) {
      _currentContext = widget.initialContext;
      _addPredictionContext(widget.initialContext!);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _savePersistedMessages();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== PERSISTENCE ====================

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

  // ==================== MESSAGE MANAGEMENT ====================

  void _addWelcomeMessage() {
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        text:
            "Hello Doctor! 👋 I'm HeartBot.\n\nI can help you understand heart disease risk factors, explain medical terms, and support your clinical decisions. How can I assist you today?",
        isUser: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ));
    }
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

  // ==================== SEND MESSAGE ====================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // If editing, update the message
    if (_editingMessageId != null) {
      await _updateMessage(_editingMessageId!, text);
      return;
    }

    _messageController.clear();
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    // Add user message
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(userMessage));
    _scrollToBottom();
    await _savePersistedMessages();

    // Send to API
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

  // ==================== MESSAGE EDITING ====================

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

  // ==================== UI HELPERS ====================

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

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = _messages[index];
    final previous = _messages[index - 1];
    final diff = current.timestamp.difference(previous.timestamp);
    return diff.inMinutes > 5;
  }

  void _clearContext() {
    setState(() => _currentContext = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Patient context cleared. You can now ask general questions.'),
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
              });
              _savePersistedMessages();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK REPLIES ====================

  List<String> _getQuickReplies() {
    if (_currentContext != null) {
      return [
        'What does this risk score mean?',
        'What treatment options exist?',
        'What lifestyle changes are recommended?',
        'What are the complications?',
        'Is further testing needed?',
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

  Widget _buildQuickReplies(Responsive r) {
    if (_isLoading) return const SizedBox.shrink();
    if (_editingMessageId != null) return const SizedBox.shrink();

    final replies = _getQuickReplies();
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
                style: TextStyle(fontSize: r.fs(11)),
              ),
              onPressed: () {
                _messageController.text = replies[index];
                _sendMessage();
              },
              backgroundColor: AppColors.sageGreen.withOpacity(0.08),
              side: BorderSide(
                color: AppColors.sageGreen.withOpacity(0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.sp(20)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== EXPORT & SAVE ====================

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
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export as PDF'),
              subtitle: const Text('PDF format with headers'),
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
      final fileName =
          'HeartBot_Conversation_${DateTime.now().millisecondsSinceEpoch}.json';
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

  Future<void> _exportAsPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 PDF export coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ==================== SAVED CONVERSATIONS ====================

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
        });
        _savePersistedMessages();
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

  // ==================== KNOWLEDGE BASE ====================

  void _openKnowledgeBase() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _KnowledgeBaseSheet(),
    );
  }

  // ==================== COPY & STATS ====================

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

  void _showConversationStats() {
    final userMessages = _messages.where((m) => m.isUser).length;
    final botMessages =
        _messages.where((m) => !m.isUser && !(m.isSystem == true)).length;
    final systemMessages = _messages.where((m) => m.isSystem == true).length;
    final totalMessages = _messages.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Conversation Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatRow(label: 'Total Messages', value: '$totalMessages'),
            _StatRow(label: 'Your Messages', value: '$userMessages'),
            _StatRow(label: 'HeartBot Responses', value: '$botMessages'),
            _StatRow(label: 'System Messages', value: '$systemMessages'),
            const Divider(),
            _StatRow(
                label: 'Patient Context',
                value: _currentContext != null ? 'Active' : 'None'),
            _StatRow(
                label: 'Conversation Length',
                value: '${_chatbot.historyLength} exchanges'),
            if (_typingSpeed > 0)
              _StatRow(
                  label: 'Avg Response Time',
                  value: '${_typingSpeed}s'),
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _buildAppBar(r, t, isDesktop),
      body: _buildBody(r, t, isDesktop),
    );
  }

  PreferredSizeWidget _buildAppBar(Responsive r, AppThemeTokens t,
      bool isDesktop) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: isDesktop ? 36 : r.wp(32),
            height: isDesktop ? 36 : r.wp(32),
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              color: AppColors.sageGreen,
              size: isDesktop ? 18 : r.wp(17),
            ),
          ),
          SizedBox(width: r.wp(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HeartBot',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : r.fs(16),
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _chatbot.historyLength > 1
                          ? Colors.green
                          : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentContext != null
                        ? 'Patient context active'
                        : _chatbot.historyLength > 1
                            ? 'Active conversation'
                            : 'Ready to help',
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : r.fs(11),
                      color: _currentContext != null
                          ? AppColors.sageGreen
                          : t.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      backgroundColor: t.bg,
      elevation: 0,
      foregroundColor: t.textPrimary,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: t.border),
      ),
      actions: [
        // Stats
        IconButton(
          icon: Icon(Icons.bar_chart_rounded, color: t.textMuted),
          onPressed: _messages.length > 1 ? _showConversationStats : null,
          tooltip: 'Conversation Stats',
        ),
        // Knowledge base
        IconButton(
          icon: Icon(Icons.library_books_outlined, color: t.textMuted),
          onPressed: _openKnowledgeBase,
          tooltip: 'Knowledge Base',
        ),
        // Export
        IconButton(
          icon: Icon(Icons.share_outlined, color: t.textMuted),
          onPressed: _messages.length > 1 ? _showExportOptions : null,
          tooltip: 'Export conversation',
        ),
        // Saved conversations
        IconButton(
          icon: Icon(Icons.folder_outlined, color: t.textMuted),
          onPressed: _viewSavedConversations,
          tooltip: 'Saved conversations',
        ),
        // Copy last response
        if (_messages.isNotEmpty && !_messages.last.isUser)
          IconButton(
            icon: Icon(Icons.copy_outlined, color: t.textMuted),
            onPressed: _copyLastResponse,
            tooltip: 'Copy last response',
          ),
        // Clear chat
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: _messages.length > 1 ? Colors.red.shade400 : t.textMuted,
          ),
          onPressed: _messages.length > 1 ? _clearChat : null,
          tooltip: 'Clear chat history',
        ),
        // Clear context
        if (_currentContext != null)
          Padding(
            padding: EdgeInsets.only(right: isDesktop ? 16 : r.wp(8)),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.clear_all,
                  size: 16,
                  color: Colors.red.shade400,
                ),
              ),
              onPressed: _clearContext,
              tooltip: 'Clear patient context',
            ),
          ),
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
                  VerticalDivider(width: 1, thickness: 1,
                      color: t.border.withOpacity(0.5)),
                  _PatientContextSidebar(
                      contextData: _currentContext!, r: r, t: t),
                ],
              ],
            )
          : _buildChatContent(r, t),
    );
  }

  Widget _buildChatContent(Responsive r, AppThemeTokens t) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width >= 900 ? 24 : r.hp,
              vertical: r.sp(16),
            ),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
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
                  ),
                ],
              );
            },
          ),
        ),
        // Quick replies
        _buildQuickReplies(r),
        // Error banner
        if (_hasError && _errorMessage != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400,
                    size: r.sp(16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700,
                        fontSize: r.fs(12)),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: r.sp(16)),
                  onPressed: () => setState(() => _hasError = false),
                ),
              ],
            ),
          ),
        // Typing indicator
        if (_isLoading) _buildTypingIndicator(r),
        // Editing indicator
        if (_editingMessageId != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.edit_rounded, color: Colors.blue.shade400,
                    size: r.sp(16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing message...',
                    style: TextStyle(color: Colors.blue.shade700,
                        fontSize: r.fs(12)),
                  ),
                ),
                TextButton(
                  onPressed: _cancelEditing,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        // ==================== DISCLAIMER BANNER ====================
        _buildDisclaimerBanner(r, t),  // ADD THIS
        // Input bar
        _buildInputBar(r, t),
      ],
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

  Widget _buildTypingIndicator(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width >= 900 ? 24 : r.hp,
        vertical: r.sp(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.wp(16),
            vertical: r.sp(12),
          ),
          decoration: BoxDecoration(
            color: AppThemeTokens.of(context).card,
            borderRadius: BorderRadius.circular(r.sp(18)),
            border: Border.all(
              color: AppColors.sageGreen.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDot(delay: 0),
              SizedBox(width: r.wp(4)),
              _TypingDot(delay: 150),
              SizedBox(width: r.wp(4)),
              _TypingDot(delay: 300),
              SizedBox(width: r.wp(8)),
              Text(
                'Thinking${_typingSpeed > 3 ? '...' : '.'}',
                style: TextStyle(
                  fontSize: r.fs(12),
                  color: AppThemeTokens.of(context).textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Responsive r, AppThemeTokens t) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : r.hp,
        vertical: r.sp(12),
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: [
          BoxShadow(
            color: t.textPrimary.withOpacity(0.04),
            blurRadius: 12,
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
                      borderRadius: BorderRadius.circular(r.sp(22)),
                      border: Border.all(
                        color: _hasError ? Colors.red : t.border,
                      ),
                    ),
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
                          horizontal: r.wp(16),
                          vertical: r.sp(12),
                        ),
                        prefixIcon: _editingMessageId != null
                            ? Icon(Icons.edit_rounded,
                                color: Colors.blue.shade400, size: r.sp(18))
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
                ),
                SizedBox(width: r.wp(10)),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: isDesktop ? 44 : r.wp(46),
                    height: isDesktop ? 44 : r.wp(46),
                    decoration: BoxDecoration(
                      color: _isLoading ? t.textMuted : AppColors.sageGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sageGreen.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                      size: isDesktop ? 18 : r.wp(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildDisclaimerBanner(Responsive r, AppThemeTokens t) {
  return GestureDetector(
    onTap: _showFullDisclaimer,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.hp,
        vertical: r.sp(6),
      ),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withOpacity(0.06),
        border: Border(
          top: BorderSide(
            color: AppColors.sageGreen.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_information_rounded,
            color: AppColors.sageGreen.withOpacity(0.5),
            size: r.sp(14),
          ),
          SizedBox(width: r.wp(6)),
          Text(
            'AI-generated, for clinical reference only',
            style: TextStyle(
              fontSize: r.fs(11),
              color: t.textMuted.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: r.wp(6)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.wp(4),
              vertical: r.sp(2),
            ),
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.sp(12)),
            ),
            child: Text(
              'Tap for info',
              style: TextStyle(
                fontSize: r.fs(9),
                color: AppColors.sageGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Add this method to _ChatbotScreenState
void _showFullDisclaimer() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.medical_information_rounded,
                  color: AppColors.sageGreen,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
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
          // Content
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HeartBot is an AI-powered clinical support tool.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '• This is NOT a medical diagnosis.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Always consult a qualified healthcare professional.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Information is for educational and reference purposes only.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Clinical judgment should always take precedence.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Verify all information before clinical use.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Never rely solely on AI for medical decisions.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• In emergencies, call emergency services immediately.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Text(
                  '• Your use of this tool is at your own risk.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
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
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Colors.blue,
                    size: 24,
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
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        '${_filteredConversations.length} conversations saved',
                        style: TextStyle(
                          fontSize: r.fs(12),
                          color: t.textMuted,
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
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search conversations...',
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
          const SizedBox(height: 8),
          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Newest',
                  selected: _sortBy == 'newest',
                  onTap: () => setState(() => _sortBy = 'newest'),
                ),
                const SizedBox(width: 4),
                _SortChip(
                  label: 'Oldest',
                  selected: _sortBy == 'oldest',
                  onTap: () => setState(() => _sortBy = 'oldest'),
                ),
                const SizedBox(width: 4),
                _SortChip(
                  label: 'Name',
                  selected: _sortBy == 'name',
                  onTap: () => setState(() => _sortBy = 'name'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // List
          Expanded(
            child: _filteredConversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: t.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No conversations match your search'
                              : 'No saved conversations yet',
                          style: TextStyle(
                            fontSize: r.fs(14),
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
                    padding: const EdgeInsets.all(16),
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
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: t.card,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: t.border.withOpacity(0.5)),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasContext
                                  ? AppColors.sageGreen.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              hasContext
                                  ? Icons.assignment_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              color: hasContext ? AppColors.sageGreen : Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Row(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.sageGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Patient',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.sageGreen,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (preview.isNotEmpty)
                                Text(
                                  preview,
                                  style: TextStyle(
                                    fontSize: r.fs(12),
                                    color: t.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: r.fs(10),
                                      color: t.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$length messages',
                                    style: TextStyle(
                                      fontSize: r.fs(10),
                                      color: t.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.download_rounded,
                                  color: AppColors.sageGreen,
                                  size: 20,
                                ),
                                onPressed: () => widget.onLoad(id),
                                tooltip: 'Load conversation',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.orange.shade400,
                                  size: 20,
                                ),
                                onPressed: () => _showRenameDialog(id, name),
                                tooltip: 'Rename',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDelete(id, name),
                                tooltip: 'Delete conversation',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.sageGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ==================== CHAT BUBBLE ====================

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Responsive r;
  final bool isDesktop;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ChatBubble({
    required this.message,
    required this.r,
    this.isDesktop = false,
    this.onCopy,
    this.onEdit,
    this.onDelete,
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
                // Copy
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(context);
                    onCopy?.call();
                  },
                ),
                // Edit (only for user messages)
                if (isUser)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(context);
                      onEdit?.call();
                    },
                  ),
                // Delete
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
            Container(
              margin: EdgeInsets.only(
                top: r.sp(4),
                bottom: r.sp(2),
                left: isUser ? (isDesktop ? 120 : r.wp(48)) : 0,
                right: isUser ? 0 : (isDesktop ? 120 : r.wp(48)),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: r.wp(14),
                vertical: r.sp(11),
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.sageGreen
                    : message.isError == true
                        ? Colors.red.shade50
                        : t.card,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r.sp(18)),
                  topRight: Radius.circular(r.sp(18)),
                  bottomLeft: Radius.circular(isUser ? r.sp(18) : r.sp(4)),
                  bottomRight: Radius.circular(isUser ? r.sp(4) : r.sp(18)),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: message.isError == true
                            ? Colors.red.shade200
                            : AppColors.sageGreen.withOpacity(0.20),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppColors.sageGreen : t.textPrimary)
                        .withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : message.isError == true
                          ? Colors.red.shade700
                          : t.textPrimary,
                  fontSize: r.fs(14),
                  height: 1.45,
                ),
              ),
            ),
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
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
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
          // Search bar
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
          // List
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
                // Demographics Card
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

                // Risk Metrics Card
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

                // Clinical Vitals Card
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