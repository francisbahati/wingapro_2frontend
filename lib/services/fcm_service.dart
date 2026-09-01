// lib/services/fcm_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'notification_service.dart';

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final NotificationService _notificationService = NotificationService();

  // Call this after login
  static Future<void> init() async {
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ FCM permission denied.');
      return;
    }

    // Get token and send to backend
    String? token = await _fcm.getToken();
    if (token != null) {
      await _registerToken(token);
    } else {
      debugPrint('❌ Failed to get FCM token.');
    }

    // ✅ Listen to foreground messages – update unread count on any message
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.notification?.title}');
      // Trigger notification service to refresh unread count
      _notificationService.onFcmMessageReceived();
    });

    // When app is opened from a terminated/background state
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // When app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  static Future<void> _registerToken(String token) async {
    try {
      final auth = AuthService();
      final jwt = await auth.getToken();
      if (jwt == null) return;
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'fcmToken': token}),
      );
      if (response.statusCode == 200) {
        debugPrint('✅ FCM token registered.');
      } else {
        debugPrint('❌ Failed to register FCM token: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ FCM token registration error: $e');
    }
  }

  static void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final relatedId = int.tryParse(data['relatedOrderId'] ?? '');
    // Navigate to appropriate screen based on type
    // You can use a global navigator key or a provider
    debugPrint('📱 Notification tapped: $type, relatedId: $relatedId');
    // TODO: Implement navigation logic
  }

  // Optional: refresh token if needed (e.g., on token refresh)
  static Future<void> refreshToken() async {
    String? newToken = await _fcm.getToken();
    if (newToken != null) {
      await _registerToken(newToken);
    }
  }
}