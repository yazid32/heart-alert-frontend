// lib/screens/auth_wrapper.dart - Fixed with timeout protection

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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  User? _user;
  String? _error;
  bool _hasSeenOnboarding = false;
  String? _inviteToken;

  @override
  void initState() {
    super.initState();
    // ✅ Use a timer to prevent infinite loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppWithTimeout();
    });
  }

  Future<void> _initializeAppWithTimeout() async {
    // ✅ Race between initialization and timeout
    try {
      await Future.any([
        _initializeApp(),
        Future.delayed(const Duration(seconds: 8), () {
          throw Exception('Initialization timed out');
        }),
      ]);
    } catch (e) {
      print('❌ AuthWrapper initialization error or timeout: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

 Future<void> _initializeApp() async {
  try {
    print('🔄 AuthWrapper: Initializing...');
    
    // ✅ Check for invite token on web
    if (kIsWeb) {
      _inviteToken = _extractInviteToken();
      if (_inviteToken != null) {
        print('📧 Found invite token: $_inviteToken');
      }
    }

    // ✅ Load all data in parallel with explicit typing
    final results = await Future.wait([
      _checkInviteToken().timeout(const Duration(seconds: 3)),
      _checkLoginStatus().timeout(const Duration(seconds: 3), onTimeout: () => false),
      _checkOnboardingStatus().timeout(const Duration(seconds: 3), onTimeout: () => false),
    ]);

    // ✅ Explicitly cast the results
    _inviteToken = results[0] as String?;
    _isLoggedIn = results[1] as bool;
    _hasSeenOnboarding = results[2] as bool;

    // ✅ If logged in, fetch user data
    if (_isLoggedIn) {
      _user = await _getUserData().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ getUserData timeout - clearing token');
          TokenService.deleteToken();
          return null;
        },
      );
      // If user is null after fetch, clear login state
      if (_user == null) {
        _isLoggedIn = false;
      }
    }

    print('✅ AuthWrapper initialization complete');
    print('   Logged in: $_isLoggedIn');
    print('   Has user: ${_user != null}');
    print('   Has seen onboarding: $_hasSeenOnboarding');
    
  } catch (e) {
    print('❌ AuthWrapper initialization error: $e');
    _error = e.toString();
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  String? _extractInviteToken() {
    try {
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
      return inviteToken;
    } catch (e) {
      print('❌ Error extracting invite token: $e');
      return null;
    }
  }

  Future<String?> _checkInviteToken() async => _inviteToken;

  Future<bool> _checkLoginStatus() async {
    try {
      return await TokenService.isLoggedIn();
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_seen_onboarding') ?? false;
    } catch (e) {
      print('❌ Error checking onboarding: $e');
      return false;
    }
  }

  Future<User?> _getUserData() async {
    try {
      return await TokenService.getUser();
    } catch (e) {
      print('❌ Error getting user data: $e');
      await TokenService.deleteToken();
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.sageGreen,
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppColors.sageGreen,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    // ✅ Handle invite token flow
    if (_inviteToken != null && _inviteToken!.isNotEmpty) {
      return _buildInvitationHandler();
    }

    // ✅ Handle logged in flow
    if (_isLoggedIn && _user != null) {
      return _buildHomeScreen();
    }

    // ✅ Handle onboarding flow
    if (!_hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    // ✅ Default: Login screen
    return const LoginScreen();
  }

  Widget _buildHomeScreen() {
    final user = _user!;

    // Check if user is pending approval
    if (user.status == 'pending') {
      return WaitingApprovalScreen(email: user.email);
    }

    // Check if user is suspended
    if (user.status == 'suspended') {
      return _buildSuspendedScreen();
    }

    // Route to appropriate home screen
    switch (user.role.toLowerCase()) {
      case 'admin':
        return const AdminHomeScreen();
      case 'hospital_admin':
        return const HospitalDashboardScreen();
      case 'assistant':
        return const AssistantHomeScreen();
      case 'doctor':
        return _buildDoctorHomeScreen();
      default:
        return const LoginScreen();
    }
  }

  Widget _buildDoctorHomeScreen() {
    final plan = (_user?.subscriptionPlan ?? _user?.plan ?? 'freemium').toLowerCase();
    if (plan == 'hospital' || plan == 'hospital_pro' || plan == 'hospital_plan') {
      return const HospitalDashboardScreen();
    }
    return const HomeScreen();
  }

  Widget _buildInvitationHandler() {
    return _InvitationHandler(inviteToken: _inviteToken!);
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _initializeAppWithTimeout();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspendedScreen() {
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
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ SIMPLIFIED INVITATION HANDLER
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

      // ✅ LOGGED IN: Accept invitation
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    foregroundColor: Colors.white,
                  ),
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