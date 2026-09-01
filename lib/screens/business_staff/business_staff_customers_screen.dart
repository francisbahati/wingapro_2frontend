// lib/screens/business_staff/business_staff_customers_screen.dart
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

class BusinessStaffCustomersScreen extends StatefulWidget {
  const BusinessStaffCustomersScreen({super.key});

  @override
  State<BusinessStaffCustomersScreen> createState() =>
      _BusinessStaffCustomersScreenState();
}

class _BusinessStaffCustomersScreenState
    extends State<BusinessStaffCustomersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  // Tanzanian phone regex
  final RegExp _phoneRegex = RegExp(r'^(0|255|\+255)?[67]\d{8}$');

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/customers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _customers = data['customers'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load customers',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchCustomers);
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

  // ─── EDIT CUSTOMER ───
  Future<void> _editCustomer(dynamic customer) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController(text: customer['username']);
    final emailController = TextEditingController(text: customer['email']);
    final phoneController = TextEditingController(text: customer['phone'] ?? '');
    bool isActive = customer['is_active'] ?? true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit Customer'),
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
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setStateDialog(() => isActive = v),
                    tileColor: Colors.transparent,
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
                final phone = phoneController.text.trim();
                if (username.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Username and Email are required'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (phone.isNotEmpty && !_phoneRegex.hasMatch(phone)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid Tanzanian mobile number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setStateDialog(() => isSubmitting = true);
                try {
                  final token = await _auth.getToken();
                  final response = await _api.put(
                    ctx,
                    '${ApiConfig.baseUrl}/api/business-staff/customers/${customer['id']}',
                    body: {
                      'username': username,
                      'email': email,
                      'phone': phone,
                      'is_active': isActive,
                    },
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 200 &&
                      data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchCustomers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Customer updated'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to update',
                    );
                  }
                } catch (e) {
                  if (mounted) showErrorSnackbar(ctx, e);
                  setStateDialog(() => isSubmitting = false);
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DELETE CUSTOMER ───
  Future<void> _deleteCustomer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/business-staff/customers/$id',
      );
      if (response.statusCode == 200) {
        _fetchCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('My Customers'),
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
        title: const Text('My Customers'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCustomers,
            color: const Color(0xFF0A2E5C),
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _customers.isEmpty
          ? const Center(child: Text('No customers found.'))
          : RefreshIndicator(
        onRefresh: _fetchCustomers,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _customers.length,
          itemBuilder: (ctx, i) {
            final c = _customers[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0A2E5C),
                  child: Text(
                    c['username'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  c['username'],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${c['email']} | ${c['phone'] ?? 'No phone'}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(c['is_active'] ? 'Active' : 'Inactive'),
                      backgroundColor: c['is_active'] ? Colors.green : Colors.red,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: _isSubmitting ? null : () => _editCustomer(c),
                    ),
                    IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      )
                          : const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isSubmitting ? null : () => _deleteCustomer(c['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}