// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import '../screens/login_screen.dart';
import 'notification_service.dart';
import 'cache_service.dart';

class AuthService {
  final storage = const FlutterSecureStorage();

  // 🔥 NEW: Track refresh state to prevent duplicate refreshes
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  // ---- Register (customer only) ----
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'role': 'customer',
      }),
    );
    return jsonDecode(response.body);
  }

  // ---- Verify Email ----
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/verify-email'),
      headers: ApiConfig.headers,
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    return jsonDecode(response.body);
  }

  // ---- Login ----
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['accessToken'] != null) {
        await storage.write(key: 'jwt_token', value: data['accessToken']);
        await storage.write(key: 'refresh_token', value: data['refreshToken']);
        if (data['user'] != null && data['user']['role'] != null) {
          await storage.write(key: 'user_role', value: data['user']['role']);
        }
        // Clear any cached data from previous session
        CacheService().clearAll();
        print('✅ Login successful, tokens stored');
        return data;
      }

      // Login failed
      print('❌ Login failed: ${data['message'] ?? 'Unknown error'}');
      return data;
    } on TimeoutException {
      print('❌ Login timeout');
      return {
        'success': false,
        'message': 'Connection timeout. Please try again.',
      };
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': 'An error occurred during login.',
      };
    }
  }

  // ---- Refresh Token (with lock to prevent race conditions) ----
  Future<String?> refreshToken() async {
    // If a refresh is already in progress, wait for it
    if (_isRefreshing && _refreshCompleter != null) {
      print('⏳ Waiting for existing token refresh...');
      return _refreshCompleter!.future;
    }

    // Start a new refresh
    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        print('❌ No refresh token stored');
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }

      print('🔄 Attempting to refresh token...');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh-token'),
        headers: ApiConfig.headers,
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['accessToken'] != null) {
        final token = data['accessToken'];
        await storage.write(key: 'jwt_token', value: token);
        print('✅ Token refreshed successfully');
        _refreshCompleter!.complete(token);
        _isRefreshing = false;
        return token;
      } else {
        print('❌ Refresh failed: ${data['message'] ?? 'Unknown error'}');
        // Clear invalid refresh token
        await storage.delete(key: 'refresh_token');
        await storage.delete(key: 'jwt_token');
        await storage.delete(key: 'user_role');
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }
    } on TimeoutException {
      print('❌ Refresh timeout');
      _refreshCompleter!.complete(null);
      _isRefreshing = false;
      return null;
    } catch (e) {
      print('❌ Refresh error: $e');
      _refreshCompleter!.complete(null);
      _isRefreshing = false;
      return null;
    }
  }

  // ---- Get stored token ----
  Future<String?> getToken() async {
    return await storage.read(key: 'jwt_token');
  }

  // ---- Get user role ----
  Future<String?> getUserRole() async {
    return await storage.read(key: 'user_role');
  }

  // ---- Forgot password ----
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  // ---- Reset password ----
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  // ---- Logout ----
  Future<void> logout() async {
    final token = await storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        // Optional: Notify the server about logout
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // Ignore server errors during logout – just clear local state
      }
    }

    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'user_role');

    // Clear all cached data
    CacheService().clearAll();

    // Reset refresh state
    _isRefreshing = false;
    _refreshCompleter = null;

    print('✅ Logged out successfully');
  }

  // ---- Force logout and navigate to login ----
  Future<void> clearAndNavigateToLogin(BuildContext context) async {
    await logout();
    NotificationService().stopPolling();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // ---- Check if token is expired (from stored token) ----
  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1].padRight(
          (parts[1].length + 3) ~/ 4 * 4,
          '=',
        ))),
      );
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp < now;
    } catch (_) {
      return true;
    }
  }

  // ---- Get token expiration time (for debugging) ----
  DateTime? getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1].padRight(
          (parts[1].length + 3) ~/ 4 * 4,
          '=',
        ))),
      );
      final exp = payload['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }
}