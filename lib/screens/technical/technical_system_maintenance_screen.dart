// lib/screens/technical/technical_system_maintenance_screen.dart
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

class TechnicalSystemMaintenanceScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalSystemMaintenanceScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalSystemMaintenanceScreen> createState() =>
      _TechnicalSystemMaintenanceScreenState();
}

class _TechnicalSystemMaintenanceScreenState
    extends State<TechnicalSystemMaintenanceScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? _status;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/maintenance',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _status = data['status']; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load maintenance status',
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

  Future<void> _toggleMaintenance(bool enable) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.post(
        context,
        '${ApiConfig.baseUrl}/api/technical/maintenance',
        body: {'enabled': enable},
      );
      if (response.statusCode == 200) {
        _fetchStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enable
                  ? 'Maintenance mode enabled'
                  : 'Maintenance mode disabled'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to toggle',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? _buildSkeletonLoading(isDark)
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
            onPressed: _fetchStatus,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _status == null
        ? const Center(child: Text('No maintenance data available.'))
        : RefreshIndicator(
      onRefresh: _fetchStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Maintenance',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Maintenance Mode'),
                  subtitle: Text(_status?['enabled'] == true
                      ? 'Enabled'
                      : 'Disabled'),
                  trailing: Switch(
                    value: _status?['enabled'] ?? false,
                    onChanged: _isProcessing
                        ? null
                        : (val) => _toggleMaintenance(val),
                    activeColor: const Color(0xFF0A2E5C),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Last Update'),
                  subtitle: Text(_status?['lastUpdate'] ?? 'N/A'),
                ),
                ListTile(
                  title: const Text('System Version'),
                  subtitle: Text(_status?['version'] ?? 'N/A'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Health',
                  style: TextStyle(
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    _status?['databaseStatus'] == 'ok'
                        ? Icons.check_circle
                        : Icons.error,
                    color: _status?['databaseStatus'] == 'ok'
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: const Text('Database'),
                  subtitle: Text(
                      _status?['databaseStatus'] ?? 'Unknown'),
                ),
                ListTile(
                  leading: Icon(
                    _status?['serverStatus'] == 'ok'
                        ? Icons.check_circle
                        : Icons.error,
                    color: _status?['serverStatus'] == 'ok'
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: const Text('Server'),
                  subtitle: Text(
                      _status?['serverStatus'] ?? 'Unknown'),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text('Maintenance'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 18, width: 150, color: Colors.grey),
                const SizedBox(height: 8),
                ListTile(
                  title: Container(height: 16, width: 100, color: Colors.grey),
                  subtitle: Container(height: 14, width: 60, color: Colors.grey),
                  trailing: Container(width: 40, height: 20, color: Colors.grey),
                ),
                const Divider(),
                ListTile(
                  title: Container(height: 16, width: 80, color: Colors.grey),
                  subtitle: Container(height: 14, width: 100, color: Colors.grey),
                ),
                ListTile(
                  title: Container(height: 16, width: 80, color: Colors.grey),
                  subtitle: Container(height: 14, width: 100, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 18, width: 120, color: Colors.grey),
                const SizedBox(height: 8),
                ...List.generate(2, (_) => ListTile(
                  leading: Icon(Icons.circle, color: Colors.grey),
                  title: Container(height: 16, width: 80, color: Colors.grey),
                  subtitle: Container(height: 14, width: 60, color: Colors.grey),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}