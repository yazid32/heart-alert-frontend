// contact_support_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart'; // Added to unify the theme

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSent = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await TokenService.getUser();
    if (user != null) {
      _nameCtrl.text = '${user.firstName} ${user.lastName}';
      _emailCtrl.text = user.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilizing your theme tokens to ensure it looks great in dark/light mode
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Contact Support'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: t.textPrimary,
        centerTitle: true,
      ),
      body: _isSent ? _buildSuccessScreen(t) : _buildForm(t),
    );
  }

  Widget _buildForm(AppThemeTokens t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600), // Prevents wide stretching on Web
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: t.card.withOpacity(t.isDark ? 1.0 : 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: AppColors.sageGreen, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How can we help?',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: t.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'We\'ll get back to you within 24 hours.',
                                  style: TextStyle(color: t.textMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      _buildModernTextField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        t: t,
                        validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildModernTextField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        t: t,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildModernTextField(
                        controller: _subjectCtrl,
                        label: 'Subject',
                        icon: Icons.short_text_rounded,
                        t: t,
                        validator: (v) => v == null || v.isEmpty ? 'Enter a subject' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildModernTextField(
                        controller: _messageCtrl,
                        label: 'Message',
                        icon: Icons.message_outlined,
                        maxLines: 5,
                        t: t,
                        validator: (v) => v == null || v.isEmpty ? 'Enter your message' : null,
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sageGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Send Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppThemeTokens t,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: t.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: maxLines == 1 
                ? Icon(icon, color: AppColors.sageGreen, size: 20) 
                : Padding(
                    padding: const EdgeInsets.only(bottom: 80.0), // Align icon to top for multiline
                    child: Icon(icon, color: AppColors.sageGreen, size: 20),
                  ),
            filled: true,
            fillColor: t.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen(AppThemeTokens t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 32),
              Text(
                'Message Sent!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: t.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for reaching out. Our support team will get back to you within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: t.textMuted, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.card,
                    foregroundColor: t.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: t.border),
                    ),
                  ),
                  child: const Text('Back to Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService.createSupportTicket(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      setState(() => _isSent = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade400),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}