// lib/screens/buyer/buyer_profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
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

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isChangingPassword = false;
  bool _isLoggingOut = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  // Change password controllers
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
        '${ApiConfig.baseUrl}/api/users/profile',
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

  Future<void> _changePassword() async {
    final oldPw = _oldPasswordController.text.trim();
    final newPw = _newPasswordController.text.trim();
    final confirmPw = _confirmPasswordController.text.trim();

    if (oldPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnackBar('Please fill all password fields', Colors.red);
      return;
    }

    if (newPw.length < 6) {
      _showSnackBar('New password must be at least 6 characters', Colors.red);
      return;
    }

    if (newPw != confirmPw) {
      _showSnackBar('New password and confirmation do not match', Colors.red);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/users/change-password',
        body: {
          'oldPassword': oldPw,
          'newPassword': newPw,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Password changed successfully!', Colors.green);
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        if (mounted) Navigator.pop(context);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to change password',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showChangePasswordDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      barrierDismissible: !_isChangingPassword,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Change Password'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password *',
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOldPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => _obscureOldPassword = !_obscureOldPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password *',
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    helperText: 'Minimum 6 characters',
                    helperStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password *',
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isChangingPassword ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
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
    final username = user?['username'] ?? 'User';
    final email = user?['email'] ?? '';
    final phone = user?['phone'] ?? '';
    final referralCode = user?['referral_code'] ?? 'N/A';
    final branch = user?['Branch']?['name'] ?? '';

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
            ProfileHeader(
              username: username,
              email: email,
              phone: phone,
              branch: branch.isNotEmpty ? branch : null,
              role: 'Customer',
            ),
            const SizedBox(height: 16),

            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF0A2E5C)),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 8),

            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              child: ListTile(
                leading: const Icon(Icons.share, color: Color(0xFF0A2E5C)),
                title: const Text('Referral Code'),
                subtitle: Text(referralCode),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Referral code: $referralCode')),
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
                leading: const Icon(Icons.settings, color: Color(0xFF0A2E5C)),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                )
                    : const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: _isLoggingOut ? null : _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}