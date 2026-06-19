// lib/screens/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/chatbot_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class ChatbotScreen extends StatefulWidget {
  final Map<String, dynamic>? initialContext;
  const ChatbotScreen({super.key, this.initialContext});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final ChatbotService _chatbot;
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  Map<String, dynamic>? _currentContext;

  @override
  void initState() {
    super.initState();
    _chatbot = ChatbotService();
    _addWelcomeMessage();
    if (widget.initialContext != null) {
      _currentContext = widget.initialContext;
      _addPredictionContext(widget.initialContext!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addPredictionContext(Map<String, dynamic> context) {
    final patientName = context['patient_name'] ?? 'Patient';
    final riskScore = (context['risk_score'] as double) * 100;
    final riskCategory = context['risk_category'];

    final clinicalSummary = '''
**PATIENT CLINICAL SUMMARY**

👤 **Demographics:**
• Name: $patientName
• Age: ${context['age']} years
• Gender: ${context['gender']}

🫀 **Clinical Measurements:**
• Chest Pain Type: ${context['chest_pain_type']}
• Resting BP: ${context['resting_bp']} mm Hg
• Cholesterol: ${context['cholesterol']} mg/dl
• Fasting Blood Sugar: ${context['fasting_blood_sugar']}
• Resting ECG: ${context['resting_ecg']}
• Max Heart Rate: ${context['max_heart_rate']} bpm
• Exercise Angina: ${context['exercise_angina']}
• ST Depression: ${context['st_depression']} mm
• ST Slope: ${context['st_slope']}

📊 **Risk Assessment:**
• Risk Score: ${riskScore.toInt()}%
• Risk Category: ${riskCategory.toUpperCase()}
• Disease Detected: ${context['has_disease'] ? 'YES' : 'NO'}

---
Ask me about these values, their clinical significance, or treatment recommendations.
''';

    _messages.add(ChatMessage(
      id: const Uuid().v4(),
      text: clinicalSummary,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: const Uuid().v4(),
      text:
          "Hello Doctor! I'm HeartBot. I can help you understand heart disease risk factors, explain medical terms, and support your clinical decisions. How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        id: const Uuid().v4(),
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = _currentContext != null
          ? await _chatbot.sendMessageWithContext(userMessage,
              context: _currentContext)
          : await _chatbot.sendMessage(userMessage);

      setState(() {
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: "I'm sorry, I'm having trouble responding. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
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

  void _clearContext() {
    setState(() => _currentContext = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Context cleared. You can now ask general questions.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget chatContent = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : r.hp, vertical: r.sp(16)),
            itemCount: _messages.length,
            itemBuilder: (context, index) =>
                _ChatBubble(message: _messages[index], r: r, isDesktop: isDesktop),
          ),
        ),

        // Typing indicator
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : r.hp, vertical: r.sp(4)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.wp(16), vertical: r.sp(12)),
                decoration: BoxDecoration(
                  color: AppThemeTokens.of(context).card,
                  borderRadius: BorderRadius.circular(r.sp(18)),
                  border: Border.all(
                      color: AppColors.sageGreen.withOpacity(0.2)),
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
          ),

        // Input bar
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : r.hp, vertical: r.sp(12)),
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
                constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: BorderRadius.circular(r.sp(22)),
                          border: Border.all(color: t.border),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                              fontSize: r.fs(14), color: t.textPrimary),
                          decoration: InputDecoration(
                            hintText: _currentContext != null
                                ? 'Ask about this patient...'
                                : 'Ask HeartBot anything...',
                            hintStyle: TextStyle(
                                fontSize: r.fs(14), color: t.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: r.wp(16), vertical: r.sp(12)),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
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
                          color: AppColors.sageGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sageGreen.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: isDesktop ? 18 : r.wp(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: isDesktop ? 36 : r.wp(32),
              height: isDesktop ? 36 : r.wp(32),
              decoration: BoxDecoration(
                color: AppColors.sageGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined,
                  color: AppColors.sageGreen, size: isDesktop ? 18 : r.wp(17)),
            ),
            SizedBox(width: r.wp(10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HeartBot',
                    style: TextStyle(
                        fontSize: isDesktop ? 16 : r.fs(16),
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary)),
                Text(
                  _currentContext != null ? 'Patient context active' : 'Ready to help',
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
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.border),
        ),
        actions: [
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
                  child: Icon(Icons.clear_all,
                      size: 16, color: Colors.red.shade400),
                ),
                onPressed: _clearContext,
                tooltip: 'Clear patient context',
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: chatContent,
                      ),
                    ),
                  ),
                  if (_currentContext != null) ...[
                    VerticalDivider(width: 1, thickness: 1, color: t.border.withOpacity(0.5)),
                    _PatientContextSidebar(contextData: _currentContext!, r: r, t: t),
                  ],
                ],
              )
            : chatContent,
      ),
    );
  }
}

// ── Patient Context Sidebar for Desktop ───────────────────────────────────────
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.textPrimary),
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.3),
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

  const _SidebarRow({required this.label, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textPrimary)),
        ],
      ),
    );
  }
}

// ── Typing dot ───────────────────────────────
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
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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

// ── Message model ────────────────────────────
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ── Chat bubble ──────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Responsive r;
  final bool isDesktop;

  const _ChatBubble({required this.message, required this.r, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeTokens.of(context);

    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: r.sp(4),
              bottom: r.sp(2),
              left: message.isUser ? (isDesktop ? 120 : r.wp(48)) : 0,
              right: message.isUser ? 0 : (isDesktop ? 120 : r.wp(48)),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: r.wp(14), vertical: r.sp(11)),
            decoration: BoxDecoration(
              color: message.isUser ? AppColors.sageGreen : t.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r.sp(18)),
                topRight: Radius.circular(r.sp(18)),
                bottomLeft: Radius.circular(message.isUser ? r.sp(18) : r.sp(4)),
                bottomRight: Radius.circular(message.isUser ? r.sp(4) : r.sp(18)),
              ),
              border: message.isUser
                  ? null
                  : Border.all(color: AppColors.sageGreen.withOpacity(0.20)),
              boxShadow: [
                BoxShadow(
                  color: (message.isUser
                          ? AppColors.sageGreen
                          : t.textPrimary)
                      .withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : t.textPrimary,
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
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(fontSize: r.fs(10), color: t.textMuted),
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