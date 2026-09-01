// lib/screens/technical/technical_staff_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class TechnicalStaffScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalStaffScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalStaffScreen> createState() => _TechnicalStaffScreenState();
}

class _TechnicalStaffScreenState extends State<TechnicalStaffScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _staff = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
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
        '${ApiConfig.baseUrl}/api/technical/staff',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _staff = data['staff'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load staff',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchStaff);
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

  Future<void> _createStaff() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'technical';
    bool isSubmitting = false;
    bool obscurePassword = true;

    // ✅ Allowed roles for technical staff to create (excludes admin)
    final List<String> allowedRoles = [
      'branch_director',
      'finance',
      'technical',
      'corporate_sales',
      'showroom',
      'business_staff',
    ];

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Create Staff User'),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setStateDialog(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ✅ Dropdown without 'admin' role
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    items: allowedRoles.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    )).toList(),
                    onChanged: (v) => setStateDialog(() => selectedRole = v!),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                final username = usernameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (username.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Fill all required fields'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => isSubmitting = true);
                try {
                  final token = await _auth.getToken();
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/technical/staff',
                    body: {
                      'username': username,
                      'email': email,
                      'phone': phoneController.text.trim(),
                      'password': password,
                      'role': selectedRole,
                    },
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 && data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchStaff();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Staff created'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to create',
                    );
                  }
                } catch (e) {
                  if (mounted) showErrorSnackbar(ctx, e);
                  setStateDialog(() => isSubmitting = false);
                }
              },
              child: isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      itemCount: 4,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : _staff.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No staff users created yet.'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _createStaff,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5C),
            ),
            child: const Text('Create Staff User'),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _staff.length,
        itemBuilder: (ctx, i) {
          final s = _staff[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  s['username']?[0]?.toUpperCase() ?? 'U',
                ),
              ),
              title: Text(
                s['username'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                '${s['email']} | ${s['role']} | ${s['phone'] ?? 'No phone'}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              trailing: Chip(
                label: Text(s['is_active'] ? 'Active' : 'Inactive'),
                backgroundColor: s['is_active'] ? Colors.green : Colors.red,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        floatingActionButton: FloatingActionButton(
          onPressed: _isSubmitting ? null : _createStaff,
          backgroundColor: const Color(0xFF0A2E5C),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Staff Management'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSubmitting ? null : _createStaff,
        backgroundColor: const Color(0xFF0A2E5C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: body,
    );
  }
}