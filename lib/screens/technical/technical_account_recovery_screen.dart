// lib/screens/technical/technical_account_recovery_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';

class TechnicalAccountRecoveryScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalAccountRecoveryScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalAccountRecoveryScreen> createState() =>
      _TechnicalAccountRecoveryScreenState();
}

class _TechnicalAccountRecoveryScreenState
    extends State<TechnicalAccountRecoveryScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _error;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/account-recovery',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _requests = data['requests']; _isLoading = false; });
        } else {
          throw Exception(data['message'] ?? 'Failed to load recovery requests');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _handleRequest(int id, String status, String reply) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/technical/account-recovery/$id',
        body: {'status': status, 'adminReply': reply},
      );
      if (response.statusCode == 200) {
        _fetchRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request updated'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showRequestDialog(dynamic request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyController =
    TextEditingController(text: request['adminReply'] ?? '');
    String selectedStatus = request['status'] ?? 'open';

    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: Text('Recovery Request #${request['id']}'),
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
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: ${request['User']?['username'] ?? 'Unknown'}',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                Text(
                  'Email: ${request['email']}',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                Text(
                  'Message: ${request['message']}',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items: ['open', 'in_progress', 'closed']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => selectedStatus = v!,
                  decoration: InputDecoration(
                    labelText: 'Status',
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
                  controller: replyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Admin Reply',
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleRequest(request['id'], selectedStatus,
                  replyController.text.trim());
            },
            child: const Text('Update'),
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
      itemCount: 4,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _error != null
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchRequests,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _requests.isEmpty
        ? const Center(child: Text('No account recovery requests.'))
        : RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (ctx, i) {
          final r = _requests[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              title: Text(
                '${r['email']} - ${r['User']?['username'] ?? 'Unknown'}',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                r['message'],
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(r['status'] ?? 'open'),
                    backgroundColor: r['status'] == 'open'
                        ? Colors.orange
                        : r['status'] == 'in_progress'
                        ? Colors.blue
                        : Colors.green,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _isUpdating
                        ? null
                        : () => _showRequestDialog(r),
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
        title: const Text('Account Recovery'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}