// lib/screens/showroom/showroom_complaints_screen.dart
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

class ShowroomComplaintsScreen extends StatefulWidget {
  final bool showAppBar;
  const ShowroomComplaintsScreen({super.key, this.showAppBar = true});

  @override
  State<ShowroomComplaintsScreen> createState() =>
      _ShowroomComplaintsScreenState();
}

class _ShowroomComplaintsScreenState extends State<ShowroomComplaintsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
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
        '${ApiConfig.baseUrl}/api/showroom/complaints',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _tickets = data['complaints'] ?? []; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load complaints',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchTickets);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTicket(int id, String status, String reply) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/showroom/complaints/$id',
        body: {'status': status, 'adminReply': reply},
      );
      if (response.statusCode == 200) {
        _fetchTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint updated'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to update',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showTicketDialog(dynamic ticket) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyController =
    TextEditingController(text: ticket['adminReply'] ?? '');
    String selectedStatus = ticket['status'] ?? 'open';

    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: Text('Complaint #${ticket['id']}'),
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
                  'User: ${ticket['User']?['username'] ?? 'Unknown'}',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                Text(
                  'Subject: ${ticket['subject']}',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                Text(
                  'Message: ${ticket['message']}',
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
              _updateTicket(ticket['id'], selectedStatus,
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
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : _tickets.isEmpty
        ? const Center(child: Text('No customer complaints.'))
        : RefreshIndicator(
      onRefresh: _fetchTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (ctx, i) {
          final t = _tickets[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              title: Text(
                t['subject'],
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                '${t['User']?['username'] ?? 'User'}: ${t['message']}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(t['status'] ?? 'open'),
                    backgroundColor: t['status'] == 'open'
                        ? Colors.orange
                        : t['status'] == 'in_progress'
                        ? Colors.blue
                        : Colors.green,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _isUpdating
                        ? null
                        : () => _showTicketDialog(t),
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
        title: const Text('Complaints'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}