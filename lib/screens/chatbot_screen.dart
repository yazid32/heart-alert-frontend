// lib/screens/chatbot_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chatbot_service.dart';
import '../services/conversation_manager.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../models/chat_message.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
class ChatbotScreen extends StatefulWidget {
  final Map<String, dynamic>? initialContext;
  const ChatbotScreen({super.key, this.initialContext});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with AutomaticKeepAliveClientMixin {
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
        text: "Hello Doctor! 👋 I'm HeartBot.\n\nI can help you understand heart disease risk factors, explain medical terms, and support your clinical decisions. How can I assist you today?",
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
    setState(() => _isLoading = true);

    try {
      final response = _currentContext != null
          ? await _chatbot.sendMessageWithContext(text, context: _currentContext)
          : await _chatbot.sendMessage(text);

      // Add bot response
      setState(() {
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      await _savePersistedMessages();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
        
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

  // Replace the _exportConversation method
  void _exportConversation() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conversation to export')),
      );
      return;
    }

    try {
      // Build the conversation text
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('═══════════════════════════════════════════════════');
      buffer.writeln('  HEARTBOT CONVERSATION EXPORT');
      buffer.writeln('  Exported: ${DateTime.now().toLocal()}');
      buffer.writeln('═══════════════════════════════════════════════════\n');
      
      for (var message in _messages) {
        final prefix = message.isUser ? '👤 Doctor' : '🤖 HeartBot';
        final time = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';
        
        // Skip system messages (welcome, context) from export
        if (message.isSystem == true && !message.isUser) {
          continue;
        }
        
        buffer.writeln('[$time] $prefix:');
        buffer.writeln(message.text);
        buffer.writeln('─' * 50);
        buffer.writeln();
      }
      
      buffer.writeln('═══════════════════════════════════════════════════');
      buffer.writeln('  End of conversation');
      buffer.writeln('  Total messages: ${_messages.where((m) => !(m.isSystem == true && !m.isUser)).length}');
      buffer.writeln('═══════════════════════════════════════════════════');
      
      final text = buffer.toString();
      
      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName = 'HeartBot_Conversation_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(text);
      
      // Share the file
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HeartBot Conversation Export',
      );
      
      // Check if share was successful
      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Conversation exported and shared successfully'),
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

  void _viewSavedConversations() async {
    try {
      final conversationIds = await ConversationManager.getConversationList();
      
      if (conversationIds.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('💾 Saved Conversations'),
            content: const Text('No saved conversations found.\n\nChat with HeartBot and export your conversations to save them.'),
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
          conversationIds: conversationIds,
          onLoad: _loadConversation,
          onDelete: _deleteConversation,
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

  Future<void> _loadConversation(String id) async {
    try {
      final messages = await ConversationManager.loadConversation(id);
      if (messages.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _chatbot.clearHistory();
          // Rebuild the chat history for the service
          for (var msg in _messages) {
            if (msg.isUser) {
              // Add user messages back to history
              // The service will rebuild its history
            }
          }
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
      // Refresh the list
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

  // Replace the _copyLastResponse method
  void _copyLastResponse() {
    if (_messages.isEmpty) return;
    
    // Find the last bot message
    final lastMessage = _messages.lastWhere(
      (msg) => !msg.isUser,
      orElse: () => _messages.last,
    );
    
    // Copy to clipboard
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

  PreferredSizeWidget _buildAppBar(Responsive r, AppThemeTokens t, bool isDesktop) {
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
                      color: _chatbot.historyLength > 1 ? Colors.green : Colors.orange,
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
        // Knowledge base
        IconButton(
          icon: Icon(Icons.library_books_outlined, color: t.textMuted),
          onPressed: _openKnowledgeBase,
          tooltip: 'Knowledge Base',
        ),
        // Export
      
        IconButton(
          icon: Icon(Icons.share_outlined, color: t.textMuted),
          onPressed: _messages.length > 1 ? _exportConversation : null,
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
                  VerticalDivider(width: 1, thickness: 1, color: t.border.withOpacity(0.5)),
                  _PatientContextSidebar(contextData: _currentContext!, r: r, t: t),
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
            itemBuilder: (context, index) => _ChatBubble(
              message: _messages[index],
              r: r,
              isDesktop: MediaQuery.of(context).size.width >= 900,
            ),
          ),
        ),
        // Error banner
        if (_hasError && _errorMessage != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.hp, vertical: r.sp(8)),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: r.sp(16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: r.fs(12)),
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
        // Input bar
        _buildInputBar(r, t),
      ],
    );
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
                        hintText: _currentContext != null
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
                        suffixIcon: _messageController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: t.textMuted,
                                  size: r.sp(16),
                                ),
                                onPressed: () => _messageController.clear(),
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
                      _isLoading ? Icons.stop_rounded : Icons.send_rounded,
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
}

// ==================== TYPING DOT ====================

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
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

class _SavedConversationsSheet extends StatelessWidget {
  final List<String> conversationIds;
  final Function(String) onLoad;
  final Function(String) onDelete;

  const _SavedConversationsSheet({
    required this.conversationIds,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                        '${conversationIds.length} conversations saved',
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
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversationIds.length,
              itemBuilder: (context, index) {
                final id = conversationIds[index];
                final date = id.split('T').first;
                final time = id.split('T').last.substring(0, 8);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Conversation',
                      style: TextStyle(
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$date at $time',
                      style: TextStyle(
                        fontSize: r.fs(12),
                        color: t.textMuted,
                      ),
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
                          onPressed: () => onLoad(id),
                          tooltip: 'Load conversation',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          onPressed: () => onDelete(id),
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
}


// ==================== CHAT BUBBLE ====================

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Responsive r;
  final bool isDesktop;

  const _ChatBubble({
    required this.message,
    required this.r,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: r.sp(4),
              bottom: r.sp(2),
              left: message.isUser ? (isDesktop ? 120 : r.wp(48)) : 0,
              right: message.isUser ? 0 : (isDesktop ? 120 : r.wp(48)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: r.wp(14),
              vertical: r.sp(11),
            ),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? AppColors.sageGreen 
                  : message.isError == true 
                      ? Colors.red.shade50
                      : t.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r.sp(18)),
                topRight: Radius.circular(r.sp(18)),
                bottomLeft: Radius.circular(message.isUser ? r.sp(18) : r.sp(4)),
                bottomRight: Radius.circular(message.isUser ? r.sp(4) : r.sp(18)),
              ),
              border: message.isUser
                  ? null
                  : Border.all(
                      color: message.isError == true 
                          ? Colors.red.shade200 
                          : AppColors.sageGreen.withOpacity(0.20),
                    ),
              boxShadow: [
                BoxShadow(
                  color: (message.isUser ? AppColors.sageGreen : t.textPrimary)
                      .withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser 
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
              left: message.isUser ? 0 : (isDesktop ? 4 : r.wp(4)),
              right: message.isUser ? (isDesktop ? 4 : r.wp(4)) : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isSystem == true && !message.isUser)
                  Icon(
                    Icons.info_outline,
                    size: r.fs(10),
                    color: t.textMuted,
                  ),
                if (message.isSystem == true && !message.isUser)
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
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
// ==================== KNOWLEDGE BASE SHEET ====================

class _KnowledgeBaseSheet extends StatelessWidget {
  const _KnowledgeBaseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    
    // Updated knowledge entries with correct icon names
final knowledgeEntries = [
  {
    'title': 'ECG Interpretation',
    'icon': Icons.favorite_rounded, // Changed from ecg_heart_rounded (doesn't exist)
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
    'icon': Icons.bloodtype, // Changed from blood_rounded (doesn't exist)
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
    'icon': Icons.bloodtype, // Changed from blood_rounded (doesn't exist)
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
                        'Clinical guidelines & references',
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
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: knowledgeEntries.length,
              itemBuilder: (context, index) {
                final entry = knowledgeEntries[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border.withOpacity(0.5)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
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
                                  color: AppColors.sageGreen.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.sageGreen.withOpacity(0.1),
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
    final riskCategory = (contextData['risk_category'] ?? 'unknown').toString().toUpperCase();
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
                Icon(Icons.assignment_ind_rounded, color: AppColors.sageGreen, size: 20),
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
                    _SidebarRow(label: 'Name', value: '${contextData['patient_name'] ?? 'Patient'}', t: t),
                    _SidebarRow(label: 'Age', value: '${contextData['age'] ?? '--'} years', t: t),
                    _SidebarRow(label: 'Gender', value: '${contextData['gender'] ?? '--'}', t: t),
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
                        Text('Risk Category', style: TextStyle(fontSize: 12, color: t.textMuted)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasDisease ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            riskCategory,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasDisease ? Colors.red.shade600 : Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Risk Score', style: TextStyle(fontSize: 12, color: t.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: riskScore / 100,
                              backgroundColor: t.border,
                              color: riskScore > 50 ? Colors.red.shade400 : AppColors.sageGreen,
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
                    _SidebarRow(label: 'Chest Pain Type', value: '${contextData['chest_pain_type'] ?? '--'}', t: t),
                    _SidebarRow(label: 'Resting BP', value: '${contextData['resting_bp'] ?? '--'} mmHg', t: t),
                    _SidebarRow(label: 'Cholesterol', value: '${contextData['cholesterol'] ?? '--'} mg/dl', t: t),
                    _SidebarRow(label: 'Fasting Blood Sugar', value: '${contextData['fasting_blood_sugar'] ?? '--'}', t: t),
                    _SidebarRow(label: 'Resting ECG', value: '${contextData['resting_ecg'] ?? '--'}', t: t),
                    _SidebarRow(label: 'Max Heart Rate', value: '${contextData['max_heart_rate'] ?? '--'} bpm', t: t),
                    _SidebarRow(label: 'Exercise Angina', value: '${contextData['exercise_angina'] ?? '--'}', t: t),
                    _SidebarRow(label: 'ST Depression', value: '${contextData['st_depression'] ?? '--'} mm', t: t),
                    _SidebarRow(label: 'ST Slope', value: '${contextData['st_slope'] ?? '--'}', t: t),
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