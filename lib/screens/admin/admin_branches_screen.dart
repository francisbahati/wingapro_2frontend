// lib/screens/admin/admin_branches_screen.dart
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

class AdminBranchesScreen extends StatefulWidget {
  const AdminBranchesScreen({super.key});

  @override
  State<AdminBranchesScreen> createState() => _AdminBranchesScreenState();
}

class _AdminBranchesScreenState extends State<AdminBranchesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _branches = [];
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/users?role=branch_director',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) setState(() => _users = data['users'] ?? []);
        }
      }
    } catch (_) {
      // Silent fail for users list - non-critical
    }
  }

  Future<void> _fetchBranches() async {
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
        '${ApiConfig.baseUrl}/api/admin/branches',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _branches = data['branches'] ?? []; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load branches',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchBranches);
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

  Future<void> _deleteBranch(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Branch'),
        content: const Text('Are you sure you want to delete this branch?'),
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
        '${ApiConfig.baseUrl}/api/admin/branches/$id',
      );
      if (response.statusCode == 200) {
        _fetchBranches();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch deleted'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete branch',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAddBranchDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    String selectedManagerId = '';
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: !isCreating,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Branch'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Branch Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedManagerId.isEmpty ? null : selectedManagerId,
                hint: const Text('Select Manager (optional)'),
                items: _users.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text('${user['username']} (${user['email']})'),
                  );
                }).toList(),
                onChanged: (value) => selectedManagerId = value ?? '',
                decoration: const InputDecoration(labelText: 'Manager'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: isCreating
                ? null
                : () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Branch name is required'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => isCreating = true);
              try {
                final token = await _auth.getToken();
                final response = await _api.post(
                  ctx,
                  '${ApiConfig.baseUrl}/api/admin/branches',
                  body: {
                    'name': name,
                    'location': locationController.text.trim(),
                    'managerId': selectedManagerId.isNotEmpty
                        ? int.parse(selectedManagerId)
                        : null,
                  },
                );
                final data = jsonDecode(response.body);
                if (response.statusCode == 201 && data['success'] == true) {
                  Navigator.pop(ctx);
                  _fetchBranches();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Branch created'),
                          backgroundColor: Colors.green),
                    );
                  }
                } else {
                  throw ApiException(
                    statusCode: response.statusCode,
                    message: data['message'] ?? 'Failed to create branch',
                  );
                }
              } catch (e) {
                if (mounted) showErrorSnackbar(ctx, e);
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

  void _showEditBranchDialog(dynamic branch) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: branch['name']);
    final locationController = TextEditingController(text: branch['location'] ?? '');
    String selectedManagerId = branch['managerId']?.toString() ?? '';
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: !isUpdating,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Branch'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Branch Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedManagerId.isEmpty ? null : selectedManagerId,
                hint: const Text('Select Manager (optional)'),
                items: _users.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text('${user['username']} (${user['email']})'),
                  );
                }).toList(),
                onChanged: (value) => selectedManagerId = value ?? '',
                decoration: const InputDecoration(labelText: 'Manager'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: isUpdating
                ? null
                : () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Branch name is required'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              setState(() => isUpdating = true);
              try {
                final token = await _auth.getToken();
                final response = await _api.put(
                  ctx,
                  '${ApiConfig.baseUrl}/api/admin/branches/${branch['id']}',
                  body: {
                    'name': name,
                    'location': locationController.text.trim(),
                    'managerId': selectedManagerId.isNotEmpty
                        ? int.parse(selectedManagerId)
                        : null,
                  },
                );
                final data = jsonDecode(response.body);
                if (response.statusCode == 200 && data['success'] == true) {
                  Navigator.pop(ctx);
                  _fetchBranches();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Branch updated'),
                          backgroundColor: Colors.green),
                    );
                  }
                } else {
                  throw ApiException(
                    statusCode: response.statusCode,
                    message: data['message'] ?? 'Failed to update branch',
                  );
                }
              } catch (e) {
                if (mounted) showErrorSnackbar(ctx, e);
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

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Manage Branches'),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: _isSubmitting ? null : _showAddBranchDialog),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBranches),
          ],
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
        title: const Text('Manage Branches'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _isSubmitting ? null : _showAddBranchDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBranches),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _branches.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No branches created yet.'),
            const SizedBox(height: 8),
            const Text('Tap + to add a branch.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchBranches,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _branches.length,
          itemBuilder: (ctx, i) {
            final b = _branches[i];
            final manager = b['manager'];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF1A1A2E).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                  child: Icon(
                    Icons.store,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                title: Text(
                  b['name'] ?? 'Unnamed Branch',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['location'] ?? 'No location',
                      style: TextStyle(
                        color: isDark ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (manager != null)
                      Text(
                        'Manager: ${manager['username'] ?? 'N/A'}',
                        style: TextStyle(
                          color: isDark ? Colors.white60
                              : Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blue),
                      onPressed: _isSubmitting ? null : () => _showEditBranchDialog(b),
                    ),
                    IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      )
                          : const Icon(Icons.delete,
                          color: Colors.red),
                      onPressed: _isSubmitting ? null : () => _deleteBranch(b['id']),
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