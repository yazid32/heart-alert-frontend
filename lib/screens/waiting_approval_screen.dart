// lib/screens/waiting_approval_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String? email;
  
  const WaitingApprovalScreen({super.key, this.email});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  bool _emailVerified = false;
  bool _checkingEmailStatus = true;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    
    // Check email verification status immediately
    _checkEmailStatus();
    
    // Start periodic check every 2 seconds (more frequent)
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (widget.email != null && mounted) {
        _checkEmailStatus();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEmailStatus() async {
    if (widget.email == null) return;
    if (!mounted) return;
    
    try {
      final isVerified = await ApiService.isEmailVerified(widget.email!);
      if (mounted) {
        // If status changed from false to true, show notification
        if (!_emailVerified && isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Email verified! Waiting for admin approval.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 15),
            ),
          );
        }
        
        setState(() {
          _emailVerified = isVerified;
          _checkingEmailStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingEmailStatus = false;
        });
      }
    }
  }

Future<void> _resendVerificationEmail() async {
  if (widget.email == null) return;
  
  setState(() => _isChecking = true);
  
  print('📧 Attempting to resend verification email to: ${widget.email}');
  
  try {
    final response = await ApiService.sendVerificationEmail(widget.email!);
    print('✅ Resend response: $response');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email resent! Please check your inbox.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    
    // Recheck status after resending
    await _checkEmailStatus();
    
  } catch (e) {
    print('❌ Resend verification failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to resend: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }
}

Future<void> _checkStatus() async {
  setState(() => _isChecking = true);

  try {
    final token = await TokenService.getToken();

    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final freshData = await ApiService.getMyStatus(token);
    final updatedUser = User.fromJson(freshData);

    await TokenService.saveUser(updatedUser);

    // ALSO CHECK EMAIL VERIFICATION STATUS
    if (widget.email != null && widget.email!.isNotEmpty) {
      final isVerified = await ApiService.isEmailVerified(widget.email!);
      if (mounted) {
        setState(() {
          _emailVerified = isVerified;
        });
        if (isVerified && !_emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Email verified! Waiting for admin approval.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

    if (updatedUser.status == 'approved') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been approved! Redirecting...'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (updatedUser.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin-home');
        } else if (updatedUser.role == 'assistant') {
          Navigator.pushReplacementNamed(context, '/assistant-home');
        } else if (updatedUser.role == 'doctor') {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } else if (updatedUser.status == 'suspended') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Your account has been suspended. Please contact support.'),
              backgroundColor: Colors.red,
            ),
        );
        await TokenService.deleteToken();
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your account is still pending approval. Please check back later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  } catch (e) {
    print('Error checking status: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error checking status. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }
}


  Future<void> _logout() async {
    await TokenService.deleteToken();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(r.hp),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon with rings
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: r.wp(120),
                        height: r.wp(120),
                        decoration: BoxDecoration(
                          color: (_emailVerified ? Colors.green : Colors.orange).withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: r.wp(96),
                        height: r.wp(96),
                        decoration: BoxDecoration(
                          color: (_emailVerified ? Colors.green : Colors.orange).withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: r.wp(72),
                        height: r.wp(72),
                        decoration: BoxDecoration(
                          color: (_emailVerified ? Colors.green : Colors.orange).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _emailVerified ? Icons.verified_outlined : Icons.pending_actions_rounded,
                          size: r.wp(36),
                          color: _emailVerified ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.sp(36)),

                // Title - changes based on verification status
                Text(
                  _emailVerified ? 'Email Verified!' : 'Pending Approval',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: r.fs(26),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.sp(12)),

                // Subtitle chip - changes based on verification status
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.wp(14), vertical: r.sp(6)),
                  decoration: BoxDecoration(
                    color: (_emailVerified ? Colors.green : Colors.orange).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _emailVerified ? 'Waiting for Admin' : 'Action Required',
                    style: TextStyle(
                      color: _emailVerified ? Colors.green.shade700 : Colors.orange.shade700,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(height: r.sp(28)),

                // Info card - shows current step
                Container(
                  padding: EdgeInsets.all(r.sp(20)),
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(r.sp(20)),
                    border: Border.all(color: t.border),
                    boxShadow: [
                      BoxShadow(
                        color: t.textPrimary.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Step 1 - Email Verification (changes when verified)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: r.wp(34),
                            height: r.wp(34),
                            decoration: BoxDecoration(
                              color: (_emailVerified ? Colors.green : AppColors.sageGreen).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _emailVerified ? Icons.check_circle : Icons.email_outlined,
                              size: r.wp(16),
                              color: _emailVerified ? Colors.green : AppColors.sageGreen,
                            ),
                          ),
                          SizedBox(width: r.wp(12)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: r.sp(6)),
                              child: Text(
                                _emailVerified 
                                    ? '✓ Email verified successfully!' 
                                    : 'Step 1: Verify your email address',
                                style: TextStyle(
                                  color: _emailVerified ? Colors.green : t.textMuted,
                                  fontSize: r.fs(13),
                                  height: 1.5,
                                  fontWeight: _emailVerified ? FontWeight.w600 : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          height: r.sp(24),
                          color: t.border.withOpacity(0.6)),
                      // Step 2 - Admin Review (always shows as pending)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: r.wp(34),
                            height: r.wp(34),
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_outlined,
                              size: r.wp(16),
                              color: AppColors.sageGreen,
                            ),
                          ),
                          SizedBox(width: r.wp(12)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: r.sp(6)),
                              child: Text(
                                'Step 2: Admin will review your credentials',
                                style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(13),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          height: r.sp(24),
                          color: t.border.withOpacity(0.6)),
                      // Step 3 - Notification (always shows as pending)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: r.wp(34),
                            height: r.wp(34),
                            decoration: BoxDecoration(
                              color: AppColors.sageGreen.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.notifications_outlined,
                              size: r.wp(16),
                              color: AppColors.sageGreen,
                            ),
                          ),
                          SizedBox(width: r.wp(12)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: r.sp(6)),
                              child: Text(
                                'Step 3: You will be notified once approved',
                                style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: r.fs(13),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.sp(24)),

                // Resend verification button (only if email not verified)
                if (!_emailVerified && widget.email != null && !_checkingEmailStatus)
                  SizedBox(
                    width: double.infinity,
                    height: r.btnH,
                    child: OutlinedButton.icon(
                      onPressed: _isChecking ? null : _resendVerificationEmail,
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Resend Verification Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sageGreen,
                        side: BorderSide(color: AppColors.sageGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.cardRadius),
                        ),
                      ),
                    ),
                  ),

                if (!_emailVerified && widget.email != null && !_checkingEmailStatus)
                  SizedBox(height: r.sp(12)),

                // Check Status Button
                SizedBox(
                  width: double.infinity,
                  height: r.btnH,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.cardRadius),
                      ),
                    ).copyWith(
                      elevation: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.pressed) ? 0 : 2,
                      ),
                      shadowColor: WidgetStateProperty.all(
                          AppColors.sageGreen.withOpacity(0.35)),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.refresh_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Check Status',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: r.sp(14)),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: r.btnH,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.textMuted,
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.cardRadius),
                      ),
                    ),
                    child: const Text('Log out',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),

                // Auto-refresh indicator text
                if (!_emailVerified)
                  Padding(
                    padding: EdgeInsets.only(top: r.sp(12)),
                    child: Text(
                      'Auto-checking every 15 seconds...',
                      style: TextStyle(
                        color: t.textMuted.withOpacity(0.5),
                        fontSize: r.fs(10),
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