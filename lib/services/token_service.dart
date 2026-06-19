// lib/services/token_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _rememberMeKey = 'remember_me';
  static const String _userKey = 'user';

  // Save tokens after login
  static Future<void> saveTokens(String accessToken, String? refreshToken, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setBool(_rememberMeKey, rememberMe);
    
    if (rememberMe && refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
    
    print('✅ Tokens saved - Access: ${accessToken.substring(0, 20)}...');
    print('✅ Remember Me: $rememberMe');
  }

  // Save only token (simple version)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  // Load access token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Save user data - FIXED: Added subscriptionPlan and plan
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode({
      'id': user.id,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'role': user.role,
      'status': user.status,
      'assigned_to': user.assignedTo,
      'specialty': user.specialty,
      'hospital': user.hospital,
      'profile_picture': user.profilePicture,
      'subscription_plan': user.subscriptionPlan,  // ✅ ADD THIS
      'plan': user.plan,                          // ✅ ADD THIS
    }));
    print('✅ User saved with role: ${user.role}, subscriptionPlan: ${user.subscriptionPlan}');
  }

  // Get current user - FIXED: Parse subscriptionPlan and plan
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        final data = json.decode(userJson);
        return User(
          id: data['id'] ?? 0,
          email: data['email'] ?? '',
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          role: data['role'] ?? 'pending',
          status: data['status'] ?? 'pending',
          profilePicture: data['profile_picture'],
          specialty: data['specialty'],
          hospital: data['hospital'],
          assignedTo: data['assigned_to'],
          subscriptionPlan: data['subscription_plan'],  // ✅ ADD THIS
          plan: data['plan'],                          // ✅ ADD THIS
        );
      } catch (e) {
        print('❌ Error parsing user: $e');
        return null;
      }
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    
    print('🔍 isLoggedIn check - Token exists: ${token != null}, Remember Me: $rememberMe');
    
    return token != null && token.isNotEmpty;
  }

  // Delete all tokens (logout)
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_userKey);
    print('🗑️ All tokens and user data deleted');
  }
  
  // Get remember me status
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }
}