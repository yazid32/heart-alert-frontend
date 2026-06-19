import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../config/app_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  bool _isSuccess = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.pop(context);

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _resetPassword() async {
    setState(() => _emailError = null);

    final email = _emailCtrl.text.trim();
    final err = _validateEmail(email);
    if (err != null) {
      setState(() => _emailError = err);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final data = json.decode(response.body);
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _isSuccess = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _emailError =
                data['detail'] ?? 'Something went wrong. Please try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Network error. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final size = MediaQuery.of(context).size;
    final t = AppThemeTokens.of(context);

    // ── Success view ──────────────────────────
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.hp),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: r.wp(100),
                    height: r.wp(100),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_outlined,
                        size: r.wp(50), color: Colors.green.shade500),
                  ),
                  SizedBox(height: r.sp(28)),
                  Text(
                    'Check Your Email',
                    style: TextStyle(
                      fontSize: r.fs(26),
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.sp(14)),
                  Container(
                    padding: EdgeInsets.all(r.sp(18)),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(r.sp(18)),
                      border: Border.all(color: t.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.email_outlined,
                            size: r.wp(28),
                            color: AppColors.sageGreen),
                        SizedBox(height: r.sp(10)),
                        Text(
                          'We sent a reset link to:',
                          style: TextStyle(
                              fontSize: r.fs(13), color: t.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: r.sp(4)),
                        Text(
                          _emailCtrl.text.trim(),
                          style: TextStyle(
                            fontSize: r.fs(14),
                            color: t.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: r.sp(8)),
                        Text(
                          'Click the link to create a new password.',
                          style: TextStyle(
                              fontSize: r.fs(12), color: t.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.sp(32)),
                  SizedBox(
                    width: double.infinity,
                    height: r.btnH,
                    child: ElevatedButton(
                      onPressed: _goBack,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sageGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.cardRadius),
                        ),
                      ),
                      child: Text('Back to Login',
                          style: TextStyle(
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Form view ─────────────────────────────
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.hp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: r.sp(34)),

                      // Back button
                      GestureDetector(
                        onTap: _goBack,
                        child: Container(
                          width: r.wp(40),
                          height: r.wp(40),
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.sageGreen.withOpacity(0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),

                      SizedBox(height: r.sp(36)),

                      // Icon accent
                      Container(
                        width: r.wp(56),
                        height: r.wp(56),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreen.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(r.sp(16)),
                        ),
                        child: Icon(Icons.lock_reset_rounded,
                            color: AppColors.sageGreen, size: r.wp(28)),
                      ),

                      SizedBox(height: r.sp(20)),

                      Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: r.fs(28),
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),

                      SizedBox(height: r.sp(8)),

                      Text(
                        'Enter your email and we\'ll send you a reset link.',
                        style: TextStyle(
                          color: t.textMuted,
                          fontSize: r.fs(14),
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: r.sp(32)),

                      _Label('Your Email', r, t),
                      SizedBox(height: r.sp(8)),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InputField(
                            controller: _emailCtrl,
                            hint: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            hasError: _emailError != null,
                            r: r,
                            t: t,
                          ),
                          if (_emailError != null)
                            Padding(
                              padding: EdgeInsets.only(
                                  top: r.sp(6), left: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 13,
                                      color: Colors.red.shade400),
                                  SizedBox(width: r.wp(4)),
                                  Text(
                                    _emailError!,
                                    style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: r.fs(12)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: r.sp(28)),

                      SizedBox(
                        width: double.infinity,
                        height: r.btnH,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sageGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(r.cardRadius),
                            ),
                          ).copyWith(
                            shadowColor: WidgetStateProperty.all(
                                AppColors.sageGreen.withOpacity(0.35)),
                            elevation: WidgetStateProperty.resolveWith(
                                (s) =>
                                    s.contains(WidgetState.pressed) ? 0 : 2),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Send Reset Link',
                                  style: TextStyle(
                                    fontSize: r.fs(15),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field label ──────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final Responsive r;
  final AppThemeTokens t;
  const _Label(this.text, this.r, this.t);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: t.textMuted,
          fontSize: r.fs(12),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}

// ── Input field ──────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final bool hasError;
  final Responsive r;
  final AppThemeTokens t;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.r,
    required this.t,
    this.keyboardType,
    this.prefixIcon,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: t.textPrimary, fontSize: r.fs(15)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: t.textMuted.withOpacity(0.6), fontSize: r.fs(14)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: t.textMuted)
            : null,
        filled: true,
        fillColor: t.surface,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 18, vertical: r.inputVPad),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide: BorderSide(
            color: hasError ? Colors.red.shade300 : t.border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide: BorderSide(
            color: hasError ? Colors.red.shade400 : AppColors.sageGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}