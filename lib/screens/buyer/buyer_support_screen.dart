// lib/screens/buyer/buyer_support_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class BuyerSupportScreen extends StatefulWidget {
  const BuyerSupportScreen({super.key});

  @override
  State<BuyerSupportScreen> createState() => _BuyerSupportScreenState();
}

class _BuyerSupportScreenState extends State<BuyerSupportScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

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
        '${ApiConfig.baseUrl}/api/tickets',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final all = data['tickets'] ?? [];
          if (mounted) {
            setState(() {
              _tickets = all.take(50).toList();
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

  Future<void> _deleteTicket(int id) async {
    final bool? confirm = await _showDeleteConfirmationDialog();
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/tickets/$id',
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _tickets.removeWhere((t) => t['id'] == id);
          });
          _showSuccessSnackbar('Ticket deleted successfully');
        }
      } else {
        final data = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to delete ticket',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ticket?'),
        content: const Text('This action cannot be undone. Are you sure?'),
        backgroundColor: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _createTicket(String subject, String message,
      {bool isDispute = false}) async {
    setState(() => _isSubmitting = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/support/ticket',
        body: {'subject': subject, 'message': message, 'dispute': isDispute},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _fetchTickets();
        _showSuccessSnackbar('Ticket sent successfully');
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to send',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showNewTicketDialog({bool isDispute = false}) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (ctx) => AlertDialog(
        title: Text(isDispute ? 'File a Dispute' : 'New Support Ticket'),
        backgroundColor: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: 'Subject *',
                filled: true,
                fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message *',
                filled: true,
                fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
              final subject = subjectController.text.trim();
              final message = messageController.text.trim();
              if (subject.isEmpty || message.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              _createTicket(subject, message, isDispute: isDispute);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5C),
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _truncate(String text, {int maxLength = 80}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Support'),
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
        title: const Text('Support'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : RefreshIndicator(
        onRefresh: _fetchTickets,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : () => _showNewTicketDialog(),
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.add),
                      label: _isSubmitting ? const Text('Sending...') : const Text('New Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2E5C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : () => _showNewTicketDialog(isDispute: true),
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.warning),
                      label: _isSubmitting ? const Text('Sending...') : const Text('Dispute'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tickets.isEmpty
                  ? const Center(child: Text('No support tickets yet.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tickets.length,
                itemBuilder: (ctx, i) {
                  final t = _tickets[i];
                  final isOpen = t['status'] == 'open';
                  final subject = _truncate(t['subject'] ?? '', maxLength: 40);
                  final message = _truncate(t['message'] ?? '', maxLength: 60);
                  final isDeleting = _isSubmitting;

                  return Dismissible(
                    key: Key(t['id'].toString()),
                    direction: isOpen ? DismissDirection.horizontal : DismissDirection.none,
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
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    subject,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(t['status'] ?? 'open'),
                                  backgroundColor: t['status'] == 'closed'
                                      ? Colors.green
                                      : Colors.orange,
                                  labelStyle: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    DateTime.parse(t['createdAt']),
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                                  ),
                                ),
                                const Spacer(),
                                if (t['adminReply'] != null && t['adminReply'].isNotEmpty)
                                  Text(
                                    'Reply: ${_truncate(t['adminReply'], maxLength: 30)}',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (isOpen)
                                  IconButton(
                                    icon: isDeleting
                                        ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.red),
                                    )
                                        : const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: isDeleting ? null : () => _deleteTicket(t['id']),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}