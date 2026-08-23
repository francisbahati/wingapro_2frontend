// lib/screens/seller/seller_profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/notification_service.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';
import '../login_screen.dart';
import '../settings_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  final bool showAppBar;
  const SellerProfileScreen({super.key, this.showAppBar = true});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  bool _isUpdating = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
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
        '${ApiConfig.baseUrl}/api/seller/profile',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _user = data['user'];
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load profile',
          );
        }
      } else if (response.statusCode == 401) {
        await _auth.clearAndNavigateToLogin(context);
        throw ApiException(statusCode: 401, message: 'Session expired');
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchProfile);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile(String username, String phone) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/seller/profile',
        body: {'username': username, 'phone': phone},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Update failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _changePassword(
      String oldPw,
      String newPw,
      BuildContext dialogContext,
      ) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/seller/change-password',
        body: {'oldPassword': oldPw, 'newPassword': newPw},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password changed successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(dialogContext);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Change failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(dialogContext, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await _auth.logout();
    NotificationService().stopPolling();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    double parsed;
    if (value is double) {
      parsed = value;
    } else if (value is int) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value) ?? 0.0;
    } else {
      parsed = 0.0;
    }
    return parsed.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    final username = user?['username'] ?? 'Seller';
    final email = user?['email'] ?? '';
    final phone = user?['phone'] ?? '';
    final balance = _formatCurrency(user?['wallet_balance']);

    String branch = '';
    if (user != null && user['Branch'] != null) {
      branch = user['Branch']['name'] ?? '';
    }

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        ),
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    Widget body = _isLoading
        ? const Center(child: SkeletonProfile())
        : RefreshIndicator(
      onRefresh: _fetchProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfileHeader(
            username: username,
            email: email,
            phone: phone,
            branch: branch.isNotEmpty ? branch : null,
            role: 'Seller',
          ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit,
                      color: Color(0xFF0A2E5C)),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: _showEditProfileDialog,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock,
                      color: Color(0xFF0A2E5C)),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.wallet,
                      color: Color(0xFF0A2E5C)),
                  title: const Text('Wallet Balance'),
                  subtitle: Text('TZS $balance'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings,
                      color: Color(0xFF0A2E5C)),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_user == null) return;
    final nameController =
    TextEditingController(text: _user?['username'] ?? '');
    final phoneController = TextEditingController(text: _user?['phone'] ?? '');
    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        backgroundColor: isDark
            ? const Color(0xFF0A1A2B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 12),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _isUpdating ? null : () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isNotEmpty) {
                _updateProfile(name, phone);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Username cannot be empty'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: _isUpdating
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        backgroundColor: isDark
            ? const Color(0xFF0A1A2B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () {
              final old = oldController.text.trim();
              final newPw = newController.text.trim();
              if (old.isEmpty || newPw.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              if (newPw.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'New password must be at least 6 characters'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              _changePassword(old, newPw, ctx);
            },
            child: _isUpdating
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update'),
          ),
        ],
      ),
    );
  }
}