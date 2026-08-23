// lib/screens/technical/technical_error_logs_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';

class TechnicalErrorLogsScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalErrorLogsScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalErrorLogsScreen> createState() =>
      _TechnicalErrorLogsScreenState();
}

class _TechnicalErrorLogsScreenState extends State<TechnicalErrorLogsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/error-logs',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _logs = data['logs']; _isLoading = false; });
        } else {
          throw Exception(data['message'] ?? 'Failed to load error logs');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
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
            onPressed: _fetchLogs,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _logs.isEmpty
        ? const Center(child: Text('No system errors or crash reports.'))
        : RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) {
          final log = _logs[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: const Icon(Icons.error,
                    color: Colors.white),
              ),
              title: Text(
                log['title'] ?? 'Error',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                log['message'] ?? 'No details',
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
              trailing: Text(
                log['timestamp']?.substring(0, 10) ?? '',
                style: TextStyle(
                  color: isDark ? Colors.white60
                      : Colors.grey.shade500,
                ),
              ),
              isThreeLine: true,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(log['title'] ?? 'Error Details'),
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
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Timestamp: ${log['timestamp'] ?? 'N/A'}'),
                          const SizedBox(height: 8),
                          Text(
                              'Message: ${log['message'] ?? 'N/A'}'),
                          const SizedBox(height: 8),
                          Text(
                              'Stack: ${log['stack'] ?? 'N/A'}'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close')),
                    ],
                  ),
                );
              },
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
        title: const Text('Error Logs'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}