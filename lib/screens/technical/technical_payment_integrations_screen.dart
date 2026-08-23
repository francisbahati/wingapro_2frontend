// lib/screens/technical/technical_payment_integrations_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';

class TechnicalPaymentIntegrationsScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalPaymentIntegrationsScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalPaymentIntegrationsScreen> createState() =>
      _TechnicalPaymentIntegrationsScreenState();
}

class _TechnicalPaymentIntegrationsScreenState
    extends State<TechnicalPaymentIntegrationsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  String? _error;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/payment-integrations',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _settings = data['settings']; _isLoading = false; });
        } else {
          throw Exception(data['message'] ?? 'Failed to load settings');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _updateSetting(String key, String value) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/technical/payment-integrations',
        body: {'key': key, 'value': value},
      );
      if (response.statusCode == 200) {
        _fetchSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting updated'), backgroundColor: Colors.green),
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

  void _showEditDialog(String key, String currentValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $key'),
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
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Value',
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _isUpdating ? null : () {
              Navigator.pop(ctx);
              _updateSetting(key, controller.text.trim());
            },
            child: _isUpdating
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
            onPressed: _fetchSettings,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _settings == null || _settings!.isEmpty
        ? const Center(
        child: Text('No payment integration settings found.'))
        : RefreshIndicator(
      onRefresh: _fetchSettings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _settings!.length,
        itemBuilder: (ctx, i) {
          final key = _settings!.keys.elementAt(i);
          final value = _settings![key];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              title: Text(
                key,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                value?.toString() ?? '',
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: _isUpdating
                    ? null
                    : () => _showEditDialog(key,
                    value?.toString() ?? ''),
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
        title: const Text('Payment Integrations'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}