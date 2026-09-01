// lib/screens/admin/admin_transactions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class AdminTransactionsScreen extends StatefulWidget {
  final bool showAppBar;

  const AdminTransactionsScreen({super.key, this.showAppBar = true});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterType = '';
  String _filterStatus = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      String url = '${ApiConfig.baseUrl}/api/admin/transactions';
      final query = [];
      if (_filterType.isNotEmpty) query.add('type=$_filterType');
      if (_filterStatus.isNotEmpty) query.add('status=$_filterStatus');
      if (_startDate != null) {
        query.add(
            'startDate=${_startDate!.toIso8601String().split('T').first}');
      }
      if (_endDate != null) {
        query.add('endDate=${_endDate!.toIso8601String().split('T').first}');
      }
      if (query.isNotEmpty) url += '?${query.join('&')}';
      final response = await _api.get(context, url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _transactions = data['transactions'] ?? [];
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load transactions',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchTransactions);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  double _totalDeposits() {
    return _transactions
        .where((t) => t['type'] == 'deposit' && t['status'] == 'completed')
        .fold(0.0, (sum, t) =>
    sum + (double.tryParse(t['amount']?.toString() ?? '0') ?? 0));
  }

  double _totalWithdrawals() {
    return _transactions
        .where((t) => t['type'] == 'withdrawal' && t['status'] == 'completed')
        .fold(0.0, (sum, t) =>
    sum + (double.tryParse(t['amount']?.toString() ?? '0') ?? 0));
  }

  int _pendingCount() {
    return _transactions.where((t) => t['status'] == 'pending').length;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _filterType.isEmpty ? null : _filterType,
              hint: const Text('Type'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All')),
                const DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
                const DropdownMenuItem(value: 'withdrawal',
                    child: Text('Withdrawal')),
              ],
              onChanged: (v) => _filterType = v ?? '',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filterStatus.isEmpty ? null : _filterStatus,
              hint: const Text('Status'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All')),
                const DropdownMenuItem(value: 'completed',
                    child: Text('Completed')),
                const DropdownMenuItem(value: 'pending', child: Text('Pending')),
                const DropdownMenuItem(value: 'failed', child: Text('Failed')),
              ],
              onChanged: (v) => _filterStatus = v ?? '',
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)'),
              onChanged: (v) => setState(() =>
              _startDate = v.isNotEmpty ? DateTime.tryParse(v) : null),
            ),
            TextField(
              decoration: const InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)'),
              onChanged: (v) => setState(() =>
              _endDate = v.isNotEmpty ? DateTime.tryParse(v) : null),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchTransactions();
            },
            child: const Text('Apply'),
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
        : Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                  child: _summaryCard('Deposits',
                      'TZS ${_totalDeposits().toStringAsFixed(0)}',
                      Colors.green)),
              const SizedBox(width: 8),
              Expanded(
                  child: _summaryCard('Withdrawals',
                      'TZS ${_totalWithdrawals().toStringAsFixed(0)}',
                      Colors.red)),
              const SizedBox(width: 8),
              Expanded(
                  child: _summaryCard('Pending',
                      '${_pendingCount()}', Colors.orange)),
            ],
          ),
        ),
        Expanded(
          child: _transactions.isEmpty
              ? const Center(child: Text('No transactions found.'))
              : RefreshIndicator(
            onRefresh: _fetchTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (ctx, i) {
                final t = _transactions[i];
                final user = t['User'];
                final isDeposit = t['type'] == 'deposit';
                return GlassCard(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDeposit
                          ? Colors.green
                          : Colors.red,
                      child: Icon(
                          isDeposit
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: Colors.white),
                    ),
                    title: Text(
                        '${user?['username'] ?? 'Unknown'}'),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${isDeposit ? 'Deposit' : 'Withdrawal'} - ${t['method']}'),
                        Text('Amount: TZS ${t['amount']}'),
                        Text(
                            'Reference: ${t['reference'] ?? 'N/A'}'),
                        Text('Status: ${t['status']}'),
                        Text(DateFormat('dd/MM/yyyy HH:mm')
                            .format(DateTime.parse(t[
                        'createdAt']))),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(t['status'] ?? 'pending'),
                      backgroundColor:
                      _getStatusColor(t['status']),
                      labelStyle: const TextStyle(
                          color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    // ✅ If showAppBar is false, return body without extra top padding
    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: body,
      );
    }

    // ✅ Otherwise, show full screen with its own app bar
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchTransactions),
        ],
      ),
      body: body,
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}