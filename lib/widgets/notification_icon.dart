// lib/widgets/notification_icon.dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../screens/notification_screen.dart';

class NotificationIcon extends StatefulWidget {
  const NotificationIcon({super.key});

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _notificationService.addListener(_onCountChanged);
  }

  Future<void> _loadCount() async {
    final count = await _notificationService.getStoredUnreadCount();
    setState(() => _unreadCount = count);
    // Fetch fresh count from server
    await _notificationService.fetchUnreadCount();
  }

  void _onCountChanged(int count) {
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onCountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF0A2E5C);

    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none, color: iconColor),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
            // Refresh count after returning
            await _notificationService.fetchUnreadCount();
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}