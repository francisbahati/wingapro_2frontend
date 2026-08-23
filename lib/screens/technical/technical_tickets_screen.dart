// lib/screens/technical/technical_tickets_screen.dart
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
      // ✅ Use the dedicated technical tickets endpoint
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/tickets',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _tickets = data['tickets'] ?? [];
            _isLoading = false;
          });
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
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
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
              trailing: Chip(
                label: Text(t['status'] ?? 'open'),
                backgroundColor: t['status'] == 'open'
                    ? Colors.orange
                    : t['status'] == 'in_progress'
                    ? Colors.blue
                    : Colors.green,
                labelStyle: const TextStyle(color: Colors.white),
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