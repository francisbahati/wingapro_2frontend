// lib/screens/corporate_sales/corporate_sales_sellers_screen.dart
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

class CorporateSalesSellersScreen extends StatefulWidget {
  final bool showAppBar;
  const CorporateSalesSellersScreen({super.key, this.showAppBar = true});

  @override
  State<CorporateSalesSellersScreen> createState() =>
      _CorporateSalesSellersScreenState();
}

class _CorporateSalesSellersScreenState
    extends State<CorporateSalesSellersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _sellers = [];
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
    _fetchSellers();
  }

  Future<void> _fetchSellers() async {
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
        '${ApiConfig.baseUrl}/api/corporate-sales/sellers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _sellers = data['sellers'] ?? []; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load sellers',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchSellers);
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

  // ─── REGISTER SELLER ───
  Future<void> _registerSeller() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Register Seller'),
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
                final phone = phoneController.text.trim();
                if (username.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Fill all required fields'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                // Validate phone if provided
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
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/corporate-sales/sellers',
                    body: {
                      'username': username,
                      'email': email,
                      'phone': phone,
                      'password': password,
                    },
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 &&
                      data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchSellers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Seller registered'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to register',
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
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── EDIT SELLER ───
  Future<void> _editSeller(dynamic seller) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController(text: seller['username']);
    final emailController = TextEditingController(text: seller['email']);
    final phoneController = TextEditingController(text: seller['phone'] ?? '');
    bool isActive = seller['is_active'] ?? true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Edit Seller'),
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
                    '${ApiConfig.baseUrl}/api/corporate-sales/sellers/${seller['id']}',
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
                    _fetchSellers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Seller updated'),
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

  // ─── DELETE SELLER ───
  Future<void> _deleteSeller(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Seller'),
        content: const Text('Are you sure you want to delete this seller?'),
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
        '${ApiConfig.baseUrl}/api/corporate-sales/sellers/$id',
      );
      if (response.statusCode == 200) {
        _fetchSellers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller deleted'), backgroundColor: Colors.green),
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
        : _sellers.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No sellers registered yet.'),
          SizedBox(height: 8),
          Text('Tap + to register a seller.'),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchSellers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sellers.length,
        itemBuilder: (ctx, i) {
          final s = _sellers[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  s['username']?[0]?.toUpperCase() ?? 'S',
                ),
              ),
              title: Text(
                s['username'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                '${s['email']} | ${s['phone'] ?? 'No phone'}',
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade700,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(s['is_active'] ? 'Active' : 'Inactive'),
                    backgroundColor:
                    s['is_active'] ? Colors.green : Colors.red,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _isSubmitting ? null : () => _editSeller(s),
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
                    onPressed: _isSubmitting ? null : () => _deleteSeller(s['id']),
                  ),
                ],
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
          onPressed: _isSubmitting ? null : _registerSeller,
          backgroundColor: const Color(0xFF0A2E5C),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Registered Sellers'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSubmitting ? null : _registerSeller,
        backgroundColor: const Color(0xFF0A2E5C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: body,
    );
  }
}