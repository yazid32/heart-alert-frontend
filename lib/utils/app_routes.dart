import 'package:flutter/material.dart';
import '../screens/intro_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/hospital_dashboard_screen.dart';
import '../screens/reset_password_screen.dart';
class AppRoutes {
  static const String intro = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset';
  static const String hospitalDashboard = '/hospital-dashboard';
static const String testUpload = '/test-upload';
  
  static Map<String, WidgetBuilder> get routes => {
    intro: (_) => const IntroScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    home: (_) => const HomeScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    resetPassword: (_) => const CreateNewPasswordScreen(token: ''),
// Add to routes map
    hospitalDashboard: (_) => const HospitalDashboardScreen(),
  };
}