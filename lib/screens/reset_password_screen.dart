import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../config/app_config.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  final String token;
  const CreateNewPasswordScreen({super.key, required this.token});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
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
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.pop(context);
  void _goToLogin() =>
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

  Future<void> _resetPassword() async {
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': widget.token,
          'new_password': _passwordCtrl.text,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });
      } else {
        final error = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: ${error['detail']}')));
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final size = MediaQuery.of(context).size;
    final t = AppThemeTokens.of(context);

    // ── Success ───────────────────────────────
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
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
                  child: Icon(Icons.lock_open_rounded,
                      size: r.wp(48), color: Colors.green.shade500),
                ),
                SizedBox(height: r.sp(28)),
                Text(
                  'Password Reset!',
                  style: TextStyle(
                    fontSize: r.fs(26),
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.sp(12)),
                Text(
                  'Your password has been changed successfully.',
                  style: TextStyle(fontSize: r.fs(14), color: t.textMuted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.sp(40)),
                SizedBox(
                  width: double.infinity,
                  height: r.btnH,
                  child: ElevatedButton(
                    onPressed: _goToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(r.cardRadius)),
                    ),
                    child: Text('Go to Login',
                        style: TextStyle(
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Form ──────────────────────────────────
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
                              size: 16),
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
                        child: Icon(Icons.lock_outline_rounded,
                            color: AppColors.sageGreen, size: r.wp(28)),
                      ),

                      SizedBox(height: r.sp(20)),

                      Text(
                        'Create new password',
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
                        'Your new password must be different from previously used passwords.',
                        style: TextStyle(
                          color: t.textMuted,
                          fontSize: r.fs(14),
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: r.sp(32)),

                      _Label('New password', r, t),
                      SizedBox(height: r.sp(8)),
                      _InputField(
                        controller: _passwordCtrl,
                        hint: '••••••••',
                        obscure: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        r: r,
                        t: t,
                        suffix: GestureDetector(
                          onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: t.textMuted,
                          ),
                        ),
                      ),

                      SizedBox(height: r.sp(20)),

                      _Label('Confirm password', r, t),
                      SizedBox(height: r.sp(8)),
                      _InputField(
                        controller: _confirmPasswordCtrl,
                        hint: '••••••••',
                        obscure: _obscureConfirmPassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        r: r,
                        t: t,
                        suffix: GestureDetector(
                          onTap: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          child: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: t.textMuted,
                          ),
                        ),
                      ),

                      SizedBox(height: r.sp(10)),

                      // Password hint
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.wp(14), vertical: r.sp(10)),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreen.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(r.sp(10)),
                          border: Border.all(
                              color: AppColors.sageGreen.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.sageGreen),
                            SizedBox(width: r.wp(8)),
                            Text(
                              'Must be at least 6 characters',
                              style: TextStyle(
                                fontSize: r.fs(12),
                                color: AppColors.sageGreen,
                              ),
                            ),
                          ],
                        ),
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
                                    BorderRadius.circular(r.cardRadius)),
                          ).copyWith(
                            shadowColor: WidgetStateProperty.all(
                                AppColors.sageGreen.withOpacity(0.35)),
                            elevation: WidgetStateProperty.resolveWith(
                                (s) =>
                                    s.contains(WidgetState.pressed) ? 0 : 2),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  'Reset Password',
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Responsive r;
  final AppThemeTokens t;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.r,
    required this.t,
    this.obscure = false,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: t.textPrimary, fontSize: r.fs(15)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: t.textMuted.withOpacity(0.6), fontSize: r.fs(14)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: t.textMuted)
            : null,
        suffixIcon: suffix,
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
          borderSide: BorderSide(color: t.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.cardRadius),
          borderSide:
              const BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
      ),
    );
  }
}