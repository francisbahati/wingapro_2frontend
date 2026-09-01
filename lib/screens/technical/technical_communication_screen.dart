// lib/screens/technical/technical_communication_screen.dart
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

class TechnicalCommunicationScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalCommunicationScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalCommunicationScreen> createState() =>
      _TechnicalCommunicationScreenState();
}

class _TechnicalCommunicationScreenState
    extends State<TechnicalCommunicationScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/communication',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _messages = data['messages']; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load messages',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  Future<void> _sendMessage(String message) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/technical/communication',
        body: {'message': message},
      );
      if (response.statusCode == 201) {
        _fetchMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to send',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSendDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: !_isSending,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Communication'),
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
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Message',
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
        actions: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSending ? null : () {
              final msg = controller.text.trim();
              if (msg.isNotEmpty) {
                Navigator.pop(ctx);
                _sendMessage(msg);
              }
            },
            child: _isSending
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send'),
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
            onPressed: _fetchMessages,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _messages.isEmpty
        ? const Center(child: Text('No communications yet.'))
        : RefreshIndicator(
      onRefresh: _fetchMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (ctx, i) {
          final m = _messages[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['message'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m['sender']?['username'] ?? 'Unknown'} - ${m['createdAt']?.substring(0, 10) ?? ''}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60
                          : Colors.grey.shade500,
                    ),
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
          onPressed: _isSending ? null : _showSendDialog,
          backgroundColor: const Color(0xFF0A2E5C),
          child: _isSending
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.send, color: Colors.white),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Communications'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSending ? null : _showSendDialog,
        backgroundColor: const Color(0xFF0A2E5C),
        child: _isSending
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.send, color: Colors.white),
      ),
      body: body,
    );
  }
}