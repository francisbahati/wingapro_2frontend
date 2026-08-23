// lib/screens/technical/technical_suspicious_transactions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';

class TechnicalSuspiciousTransactionsScreen extends StatefulWidget {
  final bool showAppBar;
  const TechnicalSuspiciousTransactionsScreen({super.key, this.showAppBar = true});

  @override
  State<TechnicalSuspiciousTransactionsScreen> createState() =>
      _TechnicalSuspiciousTransactionsScreenState();
}

class _TechnicalSuspiciousTransactionsScreenState
    extends State<TechnicalSuspiciousTransactionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/technical/suspicious-transactions',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _transactions = data['transactions']; _isLoading = false; });
        } else {
          throw Exception(data['message'] ?? 'Failed to load transactions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _flagTransaction(int id, String action) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/technical/suspicious-transactions/$id',
        body: {'action': action},
      );
      if (response.statusCode == 200) {
        _fetchTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Transaction ${action == 'block' ? 'blocked' : 'investigated'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update');
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
            onPressed: _fetchTransactions,
            child: const Text('Retry'),
          ),
        ],
      ),
    )
        : _transactions.isEmpty
        ? const Center(child: Text('No suspicious transactions.'))
        : RefreshIndicator(
      onRefresh: _fetchTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (ctx, i) {
          final t = _transactions[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: const Icon(Icons.flag,
                    color: Colors.white),
              ),
              title: Text(
                'Transaction #${t['id']} - TZS ${t['amount']}',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: ${t['User']?['username']}'),
                  Text('Reason: ${t['reason']}'),
                  Text('Status: ${t['status']}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t['status'] != 'blocked')
                    IconButton(
                      icon: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Icon(Icons.block,
                          color: Colors.red),
                      onPressed: _isProcessing
                          ? null
                          : () => _flagTransaction(t['id'],
                          'block'),
                    ),
                  if (t['status'] != 'investigated')
                    IconButton(
                      icon: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Icon(Icons.search,
                          color: Colors.blue),
                      onPressed: _isProcessing
                          ? null
                          : () => _flagTransaction(t['id'],
                          'investigate'),
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
        title: const Text('Suspicious Transactions'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}