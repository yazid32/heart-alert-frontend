// lib/screens/auth_wrapper.dart - Simplified version

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/token_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'home_screen.dart';
import 'assistant_home_screen.dart';
import 'admin_home_screen.dart';
import 'waiting_approval_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'hospital_dashboard_screen.dart';
import 'signup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ CHECK FOR INVITE TOKEN IN URL (WEB)
    if (kIsWeb) {
      final uri = Uri.base;
      String? inviteToken = uri.queryParameters['invite_token'];
      
      if (inviteToken == null || inviteToken.isEmpty) {
        final hash = uri.fragment;
        if (hash.contains('invite_token=')) {
          final startIndex = hash.indexOf('invite_token=') + 13;
          final endIndex = hash.indexOf('&', startIndex);
          if (endIndex != -1) {
            inviteToken = hash.substring(startIndex, endIndex);
          } else {
            inviteToken = hash.substring(startIndex);
          }
          inviteToken = Uri.decodeComponent(inviteToken);
        }
      }
      
      if (inviteToken != null && inviteToken.isNotEmpty) {
        print('📧 AuthWrapper: Found invite token in URL: $inviteToken');
        return _InvitationHandler(inviteToken: inviteToken);
      }
    }

    // ✅ NORMAL FLOW
    return FutureBuilder<bool>(
      future: TokenService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isLoggedIn = snapshot.data == true;
        
        if (isLoggedIn) {
          return _getHomeScreenByRole(context);
        }
        
        return _checkOnboardingSeen(context);
      },
    );
  }

  Widget _getHomeScreenByRole(BuildContext context) {
    return FutureBuilder<User?>(
      future: TokenService.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        
        if (user == null) {
          return const LoginScreen();
        }

        if (user.status == 'pending') {
          return WaitingApprovalScreen(email: user.email);
        }

        if (user.status == 'suspended') {
          return _buildSuspendedScreen(context);
        }

        switch (user.role.toLowerCase()) {
          case 'admin':
            return const AdminHomeScreen();
          case 'hospital_admin':
            return const HospitalDashboardScreen();
          case 'assistant':
            return const AssistantHomeScreen();
          case 'doctor':
            return _getDoctorHomeScreen(user);
          default:
            return const LoginScreen();
        }
      },
    );
  }

  Widget _getDoctorHomeScreen(User user) {
    final plan = (user.subscriptionPlan ?? user.plan ?? 'freemium').toLowerCase();
    if (plan == 'hospital' || plan == 'hospital_pro' || plan == 'hospital_plan') {
      return const HospitalDashboardScreen();
    }
    return const HomeScreen();
  }

  Widget _buildSuspendedScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Account Suspended',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account has been suspended.\nPlease contact support for more information.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await TokenService.deleteToken();
                if (context.mounted) {
                  if (await _hasSeenOnboarding()) {
                    Navigator.pushReplacementNamed(context, '/login');
                  } else {
                    Navigator.pushReplacementNamed(context, '/onboarding');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkOnboardingSeen(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSeenOnboarding(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final hasSeenOnboarding = snapshot.data == true;
        
        if (!hasSeenOnboarding) {
          return const OnboardingScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }
}

// ✅ SIMPLIFIED INVITATION HANDLER - Like email verification
class _InvitationHandler extends StatefulWidget {
  final String inviteToken;

  const _InvitationHandler({required this.inviteToken});

  @override
  State<_InvitationHandler> createState() => _InvitationHandlerState();
}

class _InvitationHandlerState extends State<_InvitationHandler> {
  bool _processing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processInvitation();
  }

  Future<void> _processInvitation() async {
    try {
      final token = await TokenService.getToken();
      
      // If not logged in, go to signup with token
      if (token == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignupScreen(inviteToken: widget.inviteToken),
            ),
          );
        }
        return;
      }

      // ✅ LOGGED IN: Accept invitation automatically (like email verification)
      await ApiService.acceptInvitation(token, widget.inviteToken);
      
      // Refresh user data
      final user = await TokenService.getUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invitation accepted! You now have Pro features.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate to appropriate dashboard
        if (user != null) {
          final plan = (user.subscriptionPlan ?? user.plan ?? 'freemium').toLowerCase();
          if (plan == 'hospital' || plan == 'hospital_pro' || plan == 'hospital_plan') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HospitalDashboardScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          }
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _processing = false;
      });
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final t = AppThemeTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(r.hp),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_processing) ...[
                const CircularProgressIndicator(color: AppColors.sageGreen),
                SizedBox(height: r.sp(20)),
                Text(
                  'Processing invitation...',
                  style: TextStyle(color: t.textPrimary, fontSize: r.fs(16)),
                ),
              ] else if (_error != null) ...[
                Icon(Icons.error_outline, size: r.wp(48), color: Colors.red.shade400),
                SizedBox(height: r.sp(16)),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade400),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: r.sp(20)),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}