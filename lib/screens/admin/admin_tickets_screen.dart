// lib/screens/admin/admin_tickets_screen.dart
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

class AdminTicketsScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminTicketsScreen({super.key, this.showAppBar = true});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterStatus = '';

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
      String url = '${ApiConfig.baseUrl}/api/admin/tickets';
      if (_filterStatus.isNotEmpty) url += '?status=$_filterStatus';
      final response = await _api.get(context, url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _tickets = data['tickets']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load tickets',
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

  Future<void> _deleteTicket(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ticket'),
        content: const Text('Are you sure you want to delete this ticket?'),
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

    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/admin/tickets/$id',
      );
      if (response.statusCode == 200) {
        _fetchTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket deleted'), backgroundColor: Colors.green),
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

  Future<void> _updateTicket(int id, String status, String? adminReply) async {
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/tickets/$id',
        body: {'status': status, 'adminReply': adminReply ?? ''},
      );
      if (response.statusCode == 200) {
        _fetchTickets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket updated'), backgroundColor: Colors.green),
        );
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

  void _showTicketDialog(dynamic ticket) {
    final replyController =
    TextEditingController(text: ticket['adminReply'] ?? '');
    String selectedStatus = ticket['status'] ?? 'open';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ticket #${ticket['id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${ticket['User']?['username'] ?? 'Unknown'}'),
              Text('Subject: ${ticket['subject']}'),
              Text('Message: ${ticket['message']}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: ['open', 'in_progress', 'closed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => selectedStatus = v!,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              TextField(
                controller: replyController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Admin Reply'),
              ),
            ],
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
      itemCount: 5,
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
      onRefresh: _fetchTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (ctx, i) {
          final t = _tickets[i];
          return Dismissible(
            key: Key(t['id'].toString()),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => _deleteTicket(t['id']),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: GlassCard(
              child: ListTile(
                title: Text(t['subject']),
                subtitle: Text(
                    '${t['User']?['username'] ?? 'User'}: ${t['message']}'),
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
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showTicketDialog(t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTicket(t['id']),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
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
        title: const Text('Support Tickets'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _filterStatus.isEmpty ? null : _filterStatus,
            hint: const Text('Filter'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All')),
              ...['open', 'in_progress', 'closed']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (v) {
              setState(() => _filterStatus = v ?? '');
              _fetchTickets();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchTickets),
        ],
      ),
      body: body,
    );
  }
}