// lib/screens/branch_director/branch_director_profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/notification_service.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';
import '../login_screen.dart';
import '../settings_screen.dart';

class BranchDirectorProfileScreen extends StatefulWidget {
  const BranchDirectorProfileScreen({super.key});

  @override
  State<BranchDirectorProfileScreen> createState() =>
      _BranchDirectorProfileScreenState();
}

class _BranchDirectorProfileScreenState
    extends State<BranchDirectorProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoggingOut = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

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
        '${ApiConfig.baseUrl}/api/branch-director/profile',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _user = data['user']; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load profile',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchProfile);
      if (mounted) {
        setState(() {
          _errorTitle = info.title;
          _errorMessage = info.message;
          _retryAction = info.action;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfile(String username, String phone) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/branch-director/profile',
        body: {'username': username, 'phone': phone},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
          );
        }
        _fetchProfile();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Update failed',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
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
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/branch-director/change-password',
        body: {'oldPassword': oldPw, 'newPassword': newPw},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Password changed successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(dialogContext);
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Change failed',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(dialogContext, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await _auth.logout();
    NotificationService().stopPolling();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    final branch = user?['Branch'] as Map<String, dynamic>?;
    final username = user?['username'] ?? 'User';
    final email = user?['email'] ?? '';
    final phone = user?['phone'] ?? '';
    final branchName = branch?['name'] ?? 'No branch assigned';

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('My Profile'),
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

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? const Center(child: SkeletonProfile())
          : RefreshIndicator(
        onRefresh: _fetchProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF0A2E5C),
                    child: Icon(Icons.business_center, size: 50,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Branch: $branchName',
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2E5C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Branch Director',
                      style: TextStyle(color: Color(0xFF0A2E5C)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: const Icon(Icons.edit,
                    color: Color(0xFF0A2E5C)),
                title: const Text('Edit Profile'),
                onTap: () {
                  final nameController = TextEditingController(
                      text: username);
                  final phoneController = TextEditingController(
                      text: phone);
                  showDialog(
                    context: context,
                    barrierDismissible: !_isUpdating,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Edit Profile'),
                      backgroundColor: isDark
                          ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15)
                              : Colors.grey.shade300.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Username')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                  labelText: 'Phone')),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: _isUpdating ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : () {
                            _updateProfile(
                              nameController.text.trim(),
                              phoneController.text.trim(),
                            );
                            Navigator.pop(ctx);
                          },
                          child: _isUpdating
                              ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: const Icon(Icons.lock,
                    color: Color(0xFF0A2E5C)),
                title: const Text('Change Password'),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: const Icon(Icons.settings,
                    color: Color(0xFF0A2E5C)),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: _isLoggingOut
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red),
                )
                    : const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout',
                    style: TextStyle(color: Colors.red)),
                onTap: _isLoggingOut ? null : _logout,
              ),
            ),
          ],
        ),
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
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
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