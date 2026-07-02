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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setBool(_rememberMeKey, rememberMe);
      
      if (rememberMe && refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      } else {
        await prefs.remove(_refreshTokenKey);
      }
      
      print('✅ Tokens saved - Access: ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
      print('✅ Remember Me: $rememberMe');
    } catch (e) {
      print('❌ Error saving tokens: $e');
    }
  }

  // Save only token (simple version)
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token);
      print('✅ Token saved');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  // Load access token
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  // Save user data - with better error handling
  static Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMap = {
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
        'subscription_plan': user.subscriptionPlan ?? 'freemium',
        'plan': user.plan ?? 'freemium',
      };
      await prefs.setString(_userKey, json.encode(userMap));
      print('✅ User saved with role: ${user.role}, subscriptionPlan: ${user.subscriptionPlan}');
    } catch (e) {
      print('❌ Error saving user: $e');
    }
  }

  // Get current user - with better error handling and fallback
  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson == null) {
        print('⚠️ No user data found in storage');
        return null;
      }
      
      try {
        final data = json.decode(userJson);
        
        // Ensure all required fields exist with defaults
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
          subscriptionPlan: data['subscription_plan'] ?? data['plan'] ?? 'freemium',
          plan: data['plan'] ?? data['subscription_plan'] ?? 'freemium',
        );
      } catch (e) {
        print('❌ Error parsing user data: $e');
        // If parsing fails, clear corrupted data
        await prefs.remove(_userKey);
        return null;
      }
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  // Check if user is logged in - with timeout protection
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_accessTokenKey);
      
      // Check if token exists and is not empty
      final isValid = token != null && token.isNotEmpty;
      print('🔍 isLoggedIn check - Token exists: $isValid');
      
      return isValid;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Delete all tokens (logout)
  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_userKey);
      print('🗑️ All tokens and user data deleted');
    } catch (e) {
      print('❌ Error deleting tokens: $e');
    }
  }
  
  // Get remember me status
  static Future<bool> getRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      print('❌ Error getting remember me: $e');
      return false;
    }
  }
}