// lib/screens/technical/technical_security_alerts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';

class TechnicalSecurityAlertsScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalSecurityAlertsScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalSecurityAlertsScreen> createState() =>
      _TechnicalSecurityAlertsScreenState();
}

class _TechnicalSecurityAlertsScreenState
    extends State<TechnicalSecurityAlertsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/security-alerts',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _alerts = data['alerts']; _isLoading = false; });
        } else {
          throw Exception(data['message'] ?? 'Failed to load alerts');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _resolveAlert(int id) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/technical/security-alerts/$id/resolve',
      );
      if (response.statusCode == 200) {
        _fetchAlerts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Failed to resolve');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
            onPressed: _fetchAlerts,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _alerts.isEmpty
        ? const Center(child: Text('No security alerts.'))
        : RefreshIndicator(
      onRefresh: _fetchAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        itemBuilder: (ctx, i) {
          final a = _alerts[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: a['severity'] == 'high'
                    ? Colors.red
                    : Colors.orange,
                child: const Icon(Icons.warning,
                    color: Colors.white),
              ),
              title: Text(
                a['title'],
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                '${a['description']}\n${a['timestamp']?.substring(0, 10) ?? ''}',
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(a['status'] ?? 'active'),
                    backgroundColor: a['status'] == 'resolved'
                        ? Colors.green
                        : Colors.orange,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  if (a['status'] != 'resolved')
                    IconButton(
                      icon: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Icon(Icons.check,
                          color: Colors.green),
                      onPressed: _isProcessing
                          ? null
                          : () => _resolveAlert(a['id']),
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
        title: const Text('Security Alerts'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}