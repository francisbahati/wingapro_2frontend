// lib/screens/notification_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../services/notification_service.dart';
import '../services/error_handler.dart';
import '../widgets/error_view.dart';
import '../widgets/error_snackbar.dart';
import 'buyer/buyer_orders_screen.dart';
import 'admin/admin_purchases_screen.dart';
import 'admin/admin_users_screen.dart';
import 'admin/admin_tickets_screen.dart';
import 'seller/seller_orders_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  final NotificationService _notificationService = NotificationService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _fetchNotifications();
  }

  Future<void> _getUserRole() async {
    final token = await _auth.getToken();
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length != 3) return;
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(parts[1].padRight(
            (parts[1].length + 3) ~/ 4 * 4,
            '=',
          ))),
        );
        setState(() => _userRole = payload['role']);
      } catch (_) {}
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/notifications',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _notifications = data['notifications'];
            _isLoading = false;
          });
          _markAllRead();
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load notifications',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchNotifications);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/notifications/mark-all-read',
      );
      await _notificationService.fetchUnreadCount();
    } catch (_) {}
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/notifications/$id/read',
      );
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) _notifications[index]['isRead'] = true;
      });
      await _notificationService.fetchUnreadCount();
    } catch (_) {}
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await _notificationService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  void _onNotificationTap(dynamic notification) {
    _markAsRead(notification['id']);
    final type = notification['type'] ?? '';
    if (type == 'purchase' || type == 'order_status') {
      if (_userRole == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminPurchasesScreen()),
        );
      } else if (_userRole == 'seller') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellerOrdersScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BuyerOrdersScreen()),
        );
      }
    } else if (type == 'user_registration' && _userRole == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
      );
    } else if (type == 'ticket_reply') {
      if (_userRole == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminTicketsScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64,
                color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (ctx, i) {
          final n = _notifications[i];
          final isRead = n['isRead'] ?? false;
          final notificationId = n['id'];
          return Dismissible(
            key: Key(notificationId.toString()),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => _deleteNotification(notificationId),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Card(
              elevation: 0,
              color: isDark
                  ? Colors.white.withOpacity(isRead ? 0.04 : 0.08)
                  : Colors.white.withOpacity(isRead ? 0.1 : 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
                  width: 1.5,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  n['type'] == 'purchase'
                      ? Icons.shopping_cart
                      : n['type'] == 'user_registration'
                      ? Icons.person_add
                      : n['type'] == 'ticket_reply'
                      ? Icons.support_agent
                      : n['type'] == 'order_status'
                      ? Icons.update
                      : Icons.notifications,
                  color: isRead ? Colors.grey : Theme.of(context).primaryColor,
                ),
                title: Text(
                  n['title'] ?? 'Notification',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['message'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(
                        DateTime.parse(n['createdAt']),
                      ),
                      style: TextStyle(fontSize: 10,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: !isRead
                    ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                )
                    : null,
                onTap: () => _onNotificationTap(n),
              ),
            ),
          );
        },
      ),
    );
  }
}