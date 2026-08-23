// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import '../screens/login_screen.dart';
import 'notification_service.dart';
import 'cache_service.dart';

class AuthService {
  final storage = const FlutterSecureStorage();

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
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: ApiConfig.headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true && data['accessToken'] != null) {
      // Log token expiry for debugging (removed print for production)
      final token = data['accessToken'];
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(parts[1].padRight(
            (parts[1].length + 3) ~/ 4 * 4,
            '=',
          ))),
        );
        // print removed – token expiry logging is not needed in production
      }
      await storage.write(key: 'jwt_token', value: token);
      await storage.write(key: 'refresh_token', value: data['refreshToken']);
      if (data['user'] != null && data['user']['role'] != null) {
        await storage.write(key: 'user_role', value: data['user']['role']);
      }
    }
    return data;
  }

  // ---- Refresh Token ----
  Future<String?> refreshToken() async {
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh-token'),
        headers: ApiConfig.headers,
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['accessToken'] != null) {
        final token = data['accessToken'];
        // Log new token expiry (removed print for production)
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(parts[1].padRight(
              (parts[1].length + 3) ~/ 4 * 4,
              '=',
            ))),
          );
          // print removed – token expiry logging is not needed in production
        }
        await storage.write(key: 'jwt_token', value: token);
        return token;
      }
      return null;
    } catch (e) {
      // print removed – avoid logging errors in production
      return null;
    }
  }

  // ---- Forgot password ----
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
      headers: ApiConfig.headers,
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  // ---- Reset password ----
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
      headers: ApiConfig.headers,
      body: jsonEncode({'email': email, 'otp': otp, 'newPassword': newPassword}),
    );
    return jsonDecode(response.body);
  }

  // ---- Get stored token ----
  Future<String?> getToken() async => await storage.read(key: 'jwt_token');
  Future<String?> getUserRole() async => await storage.read(key: 'user_role');

  // ---- Logout ----
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'user_role');

    // ✅ Clear all cached data so next login fetches fresh data
    CacheService().clearAll();
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
}