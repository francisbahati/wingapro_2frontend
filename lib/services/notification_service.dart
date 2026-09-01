// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/notification_model.dart';
import 'api_config.dart';
import 'auth_service.dart';

class NotificationService {
  static const _storage = FlutterSecureStorage();
  final AuthService _authService = AuthService();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int _currentUnreadCount = 0;
  final List<void Function(int)> _listeners = [];
  final List<void Function(int)> _newNotificationListeners = [];

  bool _isRefreshing = false;

  final FlutterLocalNotificationsPlugin _localPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );

    final status = await Permission.notification.request();
    if (status.isGranted) {
      print('✅ Notification permission granted.');
    } else if (status.isDenied) {
      print('⚠️ Notification permission denied.');
    } else if (status.isPermanentlyDenied) {
      print('❌ Notification permission permanently denied.');
    }

    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'wingapro_channel',
      'WINGA PRO Notifications',
      description: 'Notifications from WINGA PRO',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );
    await _localPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  static void _onNotificationTapBackground(NotificationResponse response) {
    print('Background notification tapped: ${response.payload}');
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'wingapro_channel',
      'WINGA PRO Notifications',
      channelDescription: 'Notifications from WINGA PRO',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      playSound: true,
      styleInformation: const BigTextStyleInformation(''),
    );

    final iosPlatformChannelSpecifics = DarwinNotificationDetails(
      sound: 'notification.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _localPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  void stopPolling() {
    // No-op for backward compatibility
  }

  Future<void> onFcmMessageReceived() async {
    final previousCount = _currentUnreadCount;
    await fetchUnreadCount();
    if (_currentUnreadCount > previousCount) {
      await _showLocalNotificationForNewNotifications();
      for (var l in _newNotificationListeners) {
        l(_currentUnreadCount);
      }
    }
  }

  void addListener(void Function(int count) listener) => _listeners.add(listener);
  void removeListener(void Function(int count) listener) =>
      _listeners.remove(listener);
  void addNewNotificationListener(void Function(int count) listener) =>
      _newNotificationListeners.add(listener);
  void removeNewNotificationListener(void Function(int count) listener) =>
      _newNotificationListeners.remove(listener);

  void _notifyListeners(int count) {
    for (var l in _listeners) l(count);
  }

  Future<String?> _getToken() async => await _storage.read(key: 'jwt_token');

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<int> fetchUnreadCount() async {
    if (_isRefreshing) {
      int attempts = 0;
      while (_isRefreshing && attempts < 50) {
        await Future.delayed(Duration(milliseconds: 100));
        attempts++;
      }
      return _currentUnreadCount;
    }

    try {
      final headers = await _authHeaders();
      final token = headers['Authorization'];
      if (token == null || token == 'Bearer null') return 0;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/unread-count'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['count'] ?? 0;
        if (_currentUnreadCount != count) {
          _currentUnreadCount = count;
          _notifyListeners(count);
          await _storage.write(key: 'unread_count', value: count.toString());
        }
        return count;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('🔴 Token expired, attempting refresh...');
        _isRefreshing = true;
        try {
          final newToken = await _authService.refreshToken();
          if (newToken != null) {
            print('✅ Token refreshed successfully. Retrying notification count...');
            final retryHeaders = await _authHeaders();
            final retryResponse = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/notifications/unread-count'),
              headers: retryHeaders,
            );
            if (retryResponse.statusCode == 200) {
              final data = jsonDecode(retryResponse.body);
              final count = data['count'] ?? 0;
              if (_currentUnreadCount != count) {
                _currentUnreadCount = count;
                _notifyListeners(count);
                await _storage.write(key: 'unread_count', value: count.toString());
              }
              _isRefreshing = false;
              return count;
            } else {
              print('🔴 Retry failed with status ${retryResponse.statusCode}.');
              await _authService.logout();
              _isRefreshing = false;
            }
          } else {
            print('🔴 Refresh token failed. Logging out.');
            await _authService.logout();
            _isRefreshing = false;
          }
        } catch (e) {
          print('Error during token refresh: $e');
          await _authService.logout();
          _isRefreshing = false;
        }
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
    return _currentUnreadCount;
  }

  Future<int> getStoredUnreadCount() async {
    final value = await _storage.read(key: 'unread_count');
    return int.tryParse(value ?? '0') ?? 0;
  }

  Future<List<AppNotification>> getNotifications({int page = 1, int limit = 50}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications?page=$page&limit=$limit'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['notifications'];
        return list.map((json) => AppNotification.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    return [];
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final headers = await _authHeaders();
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$notificationId/read'),
        headers: headers,
      );
      await fetchUnreadCount();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/mark-all-read'),
        headers: headers,
      );
      await fetchUnreadCount();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$notificationId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await fetchUnreadCount();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to delete notification');
      }
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  Future<void> _showLocalNotificationForNewNotifications() async {
    try {
      final notifications = await getNotifications(limit: 1);
      if (notifications.isNotEmpty) {
        final latest = notifications.first;
        await _showLocalNotification(
          id: latest.id,
          title: latest.title,
          body: latest.message,
          payload: 'notification_${latest.id}',
        );
      }
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }
}