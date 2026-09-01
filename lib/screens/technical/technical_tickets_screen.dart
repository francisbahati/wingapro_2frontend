// lib/screens/technical/technical_tickets_screen.dart
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

class TechnicalTicketsScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalTicketsScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalTicketsScreen> createState() =>
      _TechnicalTicketsScreenState();
}

class _TechnicalTicketsScreenState extends State<TechnicalTicketsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  bool _isUpdating = false;
  int? _updatingTicketId;

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
      // Use the dedicated technical tickets endpoint
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/tickets',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _tickets = data['tickets'] ?? [];
              _isLoading = false;
            });
          }
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

  // ─── UPDATE (reply + status) ───
  Future<void> _updateTicket(int id, String status, String? adminReply) async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
      _updatingTicketId = id;
    });
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/technical/tickets/$id',
        body: {'status': status, 'adminReply': adminReply ?? ''},
      );
      if (response.statusCode == 200) {
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket updated'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to update',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _updatingTicketId = null;
        });
      }
    }
  }

  // ─── DELETE ───
  Future<void> _deleteTicket(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ticket'),
        content: const Text('Are you sure you want to delete this ticket?'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
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

    setState(() {
      _isUpdating = true;
      _updatingTicketId = id;
    });
    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/technical/tickets/$id',
      );
      if (response.statusCode == 200) {
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket deleted'), backgroundColor: Colors.green),
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
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _updatingTicketId = null;
        });
      }
    }
  }

  // ─── EDIT DIALOG ───
  void _showEditDialog(dynamic ticket) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final replyController = TextEditingController(text: ticket['adminReply'] ?? '');
    String selectedStatus = ticket['status'] ?? 'open';

    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: Text('Ticket #${ticket['id']} - ${ticket['subject']}'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: ${ticket['User']?['username'] ?? 'Unknown'}',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                Text(
                  'Message: ${ticket['message']}',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  items: ['open', 'in_progress', 'closed']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => selectedStatus = v!,
                  decoration: InputDecoration(
                    labelText: 'Status',
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
                  controller: replyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Admin Reply',
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
            onPressed: _isUpdating ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () {
              Navigator.pop(ctx);
              _updateTicket(
                ticket['id'],
                selectedStatus,
                replyController.text.trim(),
              );
            },
            child: (_isUpdating && _updatingTicketId == ticket['id'])
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
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
        ? const Center(child: Text('No tickets found.'))
        : RefreshIndicator(
      onRefresh: _fetchTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (ctx, i) {
          final t = _tickets[i];
          final isDeleting = _isUpdating && _updatingTicketId == t['id'];
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
              backgroundColor: isDark
                  ? const Color(0xFF1A1A2E).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                title: Text(
                  t['subject'] ?? 'Ticket',
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
                      onPressed: _isUpdating ? null : () => _showEditDialog(t),
                    ),
                    IconButton(
                      icon: isDeleting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      )
                          : const Icon(Icons.delete, color: Colors.red),
                      onPressed: isDeleting ? null : () => _deleteTicket(t['id']),
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
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}