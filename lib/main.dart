import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/profile_screen.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/assistant_home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/waiting_approval_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'widgets/responsive_layout.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  AppConfig.flavor = Flavor.production;
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const HeartAlertApp(),
    ),
  );
}

class HeartAlertApp extends StatefulWidget {
  const HeartAlertApp({super.key});

  @override
  State<HeartAlertApp> createState() => _HeartAlertAppState();
}

class _HeartAlertAppState extends State<HeartAlertApp> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  String? _pendingToken;
  bool _isNavigatorReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize deep links with proper error handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _initDeepLinks();
      } catch (e) {
        print('❌ Deep link init failed: $e');
      }
      _isNavigatorReady = true;
      _checkForPendingToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForPendingToken();
    }
  }

  Future<void> _checkForPendingToken() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for reset token
    final pendingToken = prefs.getString('pending_reset_token');
    if (pendingToken != null && pendingToken.isNotEmpty) {
      print('🔑 Found pending reset token: $pendingToken');
      await prefs.remove('pending_reset_token');
      _navigateToResetPassword(pendingToken);
      return;
    }
    
    // Check for invite token
    final pendingInviteToken = prefs.getString('pending_invite_token');
    if (pendingInviteToken != null && pendingInviteToken.isNotEmpty) {
      print('🔑 Found pending invite token: $pendingInviteToken');
      await prefs.remove('pending_invite_token');
      _navigateToSignupWithToken(pendingInviteToken);
    }
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        String? token = initialLink.queryParameters['token'];
        String? inviteToken = initialLink.queryParameters['invite_token'];
        
        if (token != null) {
          await _savePendingToken(token);
        } else if (inviteToken != null) {
          await _savePendingInviteToken(inviteToken);
        }
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }

    _appLinks.uriLinkStream.listen((Uri uri) {
      print('📱 Deep link received while app is running: $uri');
      if (mounted) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      print('❌ Deep link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 Processing deep link: $uri');
    
    String? token;
    String? inviteToken;
    
    // Handle reset-password deep link
    if (uri.scheme == 'heartalert' && uri.host == 'reset-password') {
      token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        print('🔑 Reset token found: $token');
        _navigateToResetPassword(token);
      }
    }
    // Handle signup deep link
    else if (uri.scheme == 'heartalert' && uri.host == 'signup') {
      inviteToken = uri.queryParameters['invite_token'];
      if (inviteToken != null && inviteToken.isNotEmpty) {
        print('🔑 Invite token found for signup: $inviteToken');
        _navigateToSignupWithToken(inviteToken);
      }
    }
    else if (uri.scheme == 'http' || uri.scheme == 'https') {
      token = uri.queryParameters['token'];
      inviteToken = uri.queryParameters['invite_token'];
      print('⚠️ HTTP/HTTPS link detected.');
      
      if (inviteToken != null && inviteToken.isNotEmpty) {
        _navigateToSignupWithToken(inviteToken);
      } else if (token != null && token.isNotEmpty) {
        _navigateToResetPassword(token);
      }
    }
    
    if (token == null && inviteToken == null) {
      print('❌ No valid token found in deep link');
    }
  }

  void _navigateToResetPassword(String token) {
    print('🚀 Navigating to reset password with token: $token');
    
    if (!_isNavigatorReady || navigatorKey.currentState == null) {
      print('⚠️ Navigator not ready, saving token for later');
      _savePendingToken(token);
      return;
    }

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => CreateNewPasswordScreen(token: token),
        settings: const RouteSettings(name: '/reset-password-ui'),
      ),
    );
  }

  void _navigateToSignupWithToken(String token) {
    print('🚀 Navigating to signup with invite token: $token');
    
    if (!_isNavigatorReady || navigatorKey.currentState == null) {
      print('⚠️ Navigator not ready, saving token for later');
      _savePendingInviteToken(token);
      return;
    }

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => SignupScreen(inviteToken: token),
        settings: const RouteSettings(name: '/signup-with-token'),
      ),
    );
  }

  Future<void> _savePendingToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_reset_token', token);
    print('💾 Saved pending reset token for later');
  }

  Future<void> _savePendingInviteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_token', token);
    print('💾 Saved pending invite token for later');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Heart Alert',
      home: ResponsiveLayout(child: AuthWrapper()),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routes: {
        '/intro': (context) => const IntroScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/assistant-home': (context) => const AssistantHomeScreen(),
        '/admin-home': (context) => const AdminHomeScreen(),
        '/waiting-approval': (context) => const WaitingApprovalScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/reset-password') {
          String token = '';
          if (kIsWeb) {
            final uri = Uri.base;
            token = uri.queryParameters['token'] ?? '';
          }
          return MaterialPageRoute(
            builder: (_) => CreateNewPasswordScreen(token: token),
          );
        }
        return null;
      },
    );
  }
}