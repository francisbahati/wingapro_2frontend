// lib/screens/admin/admin_users_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class AdminUsersScreen extends StatefulWidget {
  final bool showAppBar;
  final TextEditingController? searchController;
  final String? filterRole;

  const AdminUsersScreen({
    super.key,
    this.showAppBar = true,
    this.searchController,
    this.filterRole,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _searchQuery = '';
  String _filterRole = '';
  List<dynamic> _branches = [];
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    _filterRole = widget.filterRole ?? '';

    _fetchUsers();
    _fetchBranches();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _fetchUsers();
      });
    });
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/branches',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() => _branches = data['branches']);
        }
      }
    } catch (e) {
      // Silent fail - non-critical
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      String url = '${ApiConfig.baseUrl}/api/admin/users';
      final query = [];
      if (_searchQuery.isNotEmpty) query.add('search=$_searchQuery');
      if (_filterRole.isNotEmpty) query.add('role=$_filterRole');
      if (query.isNotEmpty) url += '?${query.join('&')}';
      final response = await _api.get(context, url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _users = data['users']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load users',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchUsers);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUserActive(int id, bool current) async {
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/users/$id',
        body: {'is_active': !current},
      );
      if (response.statusCode == 200) {
        _fetchUsers();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to update',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/admin/users/$id',
      );
      if (response.statusCode == 200) {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  void _showAddUserDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'customer';
    String selectedBranchId = '';
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: !isCreating,
      builder: (ctx) => AlertDialog(
        title: const Text('Add User'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A2E).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300.withOpacity(0.5),
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
                        ? Colors.grey.shade800.withOpacity(0.5)
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
                        ? Colors.grey.shade800.withOpacity(0.5)
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
                        ? Colors.grey.shade800.withOpacity(0.5)
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
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: [
                    'customer',
                    'seller',
                    'branch_director',
                    'finance',
                    'technical',
                    'corporate_sales',
                    'showroom',
                    'business_staff'
                  ]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => selectedRole = v!,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBranchId.isEmpty ? null : selectedBranchId,
                  hint: const Text('Assign to Branch'),
                  items: _branches.map((b) => DropdownMenuItem<String>(
                    value: b['id'].toString(),
                    child: Text(b['name']),
                  )).toList(),
                  onChanged: (v) => selectedBranchId = v ?? '',
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
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
            onPressed: isCreating ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isCreating
                ? null
                : () async {
              final username = usernameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              if (username.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Username, Email, and Password are required'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => isCreating = true);
              try {
                final token = await _auth.getToken();
                if (token == null) throw Exception('Not logged in');
                final response = await _api.post(
                  ctx,
                  '${ApiConfig.baseUrl}/api/admin/users',
                  body: {
                    'username': username,
                    'email': email,
                    'phone': phoneController.text.trim(),
                    'password': password,
                    'role': selectedRole,
                    'branchId': selectedBranchId.isNotEmpty
                        ? int.parse(selectedBranchId)
                        : null,
                  },
                );
                final data = jsonDecode(response.body);
                if (response.statusCode == 201 && data['success'] == true) {
                  Navigator.pop(ctx);
                  _fetchUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('User created'),
                        backgroundColor: Colors.green),
                  );
                } else {
                  throw ApiException(
                    statusCode: response.statusCode,
                    message: data['message'] ?? 'Failed to create user',
                  );
                }
              } catch (e) {
                showErrorSnackbar(ctx, e);
                setState(() => isCreating = false);
              }
            },
            child: isCreating
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usernameController = TextEditingController(text: user['username']);
    final emailController = TextEditingController(text: user['email']);
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    String selectedRole = user['role'];
    String selectedBranchId = user['branchId']?.toString() ?? '';
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: !isUpdating,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit User'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A2E).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.15)
                : Colors.grey.shade300.withOpacity(0.5),
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
                    labelText: 'Username',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
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
                    labelText: 'Email',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
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
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: [
                    'customer',
                    'seller',
                    'branch_director',
                    'finance',
                    'technical',
                    'corporate_sales',
                    'showroom',
                    'business_staff'
                  ]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => selectedRole = v!,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBranchId.isEmpty ? null : selectedBranchId,
                  hint: const Text('Assign to Branch'),
                  items: _branches.map((b) => DropdownMenuItem<String>(
                    value: b['id'].toString(),
                    child: Text(b['name']),
                  )).toList(),
                  onChanged: (v) => selectedBranchId = v ?? '',
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withOpacity(0.5)
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
            onPressed: isUpdating ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isUpdating
                ? null
                : () async {
              final username = usernameController.text.trim();
              final email = emailController.text.trim();
              if (username.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Username and Email are required'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => isUpdating = true);
              try {
                final token = await _auth.getToken();
                if (token == null) throw Exception('Not logged in');
                final response = await _api.put(
                  ctx,
                  '${ApiConfig.baseUrl}/api/admin/users/${user['id']}',
                  body: {
                    'username': username,
                    'email': email,
                    'phone': phoneController.text.trim(),
                    'role': selectedRole,
                    'branchId': selectedBranchId.isNotEmpty
                        ? int.parse(selectedBranchId)
                        : null,
                  },
                );
                final data = jsonDecode(response.body);
                if (response.statusCode == 200 && data['success'] == true) {
                  Navigator.pop(ctx);
                  _fetchUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('User updated'),
                        backgroundColor: Colors.green),
                  );
                } else {
                  throw ApiException(
                    statusCode: response.statusCode,
                    message: data['message'] ?? 'Failed to update user',
                  );
                }
              } catch (e) {
                showErrorSnackbar(ctx, e);
                setState(() => isUpdating = false);
              }
            },
            child: isUpdating
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (ctx, i) {
          final u = _users[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF1A1A2E).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: u['is_active'] ? Colors.green : Colors.red,
                child: Text(
                  u['username'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(u['username']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${u['email']} | ${u['phone'] ?? 'No phone'}'),
                  if (u['Branch'] != null)
                    Text(
                      'Branch: ${u['Branch']['name']}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                        u['is_active'] ? Icons.visibility : Icons.visibility_off,
                        color: u['is_active'] ? Colors.green : Colors.red),
                    onPressed: () => _toggleUserActive(u['id'], u['is_active']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditUserDialog(u),
                  ),
                  if (u['role'] != 'admin')
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(u['id']),
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
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
        title: const Text('Manage Users'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddUserDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterRole.isEmpty ? null : _filterRole,
                  hint: const Text('Role'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    ...[
                      'customer',
                      'seller',
                      'branch_director',
                      'finance',
                      'technical',
                      'corporate_sales',
                      'showroom',
                      'business_staff'
                    ]
                        .map((r) => DropdownMenuItem(value: r, child: Text(r))),
                  ],
                  onChanged: (v) { _filterRole = v ?? ''; _fetchUsers(); },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchUsers,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}