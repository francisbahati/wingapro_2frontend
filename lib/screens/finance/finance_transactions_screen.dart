// lib/screens/finance/finance_transactions_screen.dart
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

class FinanceTransactionsScreen extends StatefulWidget {
  final bool showAppBar;
  const FinanceTransactionsScreen({super.key, this.showAppBar = true});

  @override
  State<FinanceTransactionsScreen> createState() =>
      _FinanceTransactionsScreenState();
}

class _FinanceTransactionsScreenState
    extends State<FinanceTransactionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterStatus = '';
  String _filterNetwork = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSearching = false;

  final List<String> _networks = ['', 'Halotel', 'Tigo', 'Vodacom', 'Airtel'];
  final List<String> _statuses = ['', 'pending', 'completed', 'failed'];

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
      String url = '${ApiConfig.baseUrl}/api/finance/transactions';
      final query = [];
      if (_filterStatus.isNotEmpty) query.add('status=$_filterStatus');
      if (_filterNetwork.isNotEmpty) query.add('network=$_filterNetwork');
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

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _isSearching = true;
      });
      _fetchTransactions();
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _isSearching = true;
      });
      _fetchTransactions();
      setState(() => _isSearching = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStatus = '';
      _filterNetwork = '';
      _startDate = null;
      _endDate = null;
      _isSearching = true;
    });
    _fetchTransactions();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: isDark ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterStatus.isEmpty ? null : _filterStatus,
                      hint: const Text('Status'),
                      items: _statuses.map((s) => DropdownMenuItem(
                        value: s.isEmpty ? null : s,
                        child: Text(s.isEmpty ? 'All' : s),
                      )).toList(),
                      onChanged: (v) {
                        setState(() { _filterStatus = v ?? ''; });
                        _fetchTransactions();
                      },
                      decoration: InputDecoration(
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filterNetwork.isEmpty ? null : _filterNetwork,
                      hint: const Text('Network'),
                      items: _networks.map((n) => DropdownMenuItem(
                        value: n.isEmpty ? null : n,
                        child: Text(n.isEmpty ? 'All' : n),
                      )).toList(),
                      onChanged: (v) {
                        setState(() { _filterNetwork = v ?? ''; });
                        _fetchTransactions();
                      },
                      decoration: InputDecoration(
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
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectStartDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800.withOpacity(0.5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18,
                                color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              _startDate == null
                                  ? 'Start Date'
                                  : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                              style: TextStyle(
                                color: _startDate == null
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectEndDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800.withOpacity(0.5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18,
                                color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              _endDate == null
                                  ? 'End Date'
                                  : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                              style: TextStyle(
                                color: _endDate == null
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearFilters,
                    tooltip: 'Clear filters',
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
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
              : _transactions.isEmpty
              ? const Center(child: Text('No transactions found.'))
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
                      backgroundColor: t['status'] == 'completed'
                          ? Colors.green
                          : Colors.orange,
                      child: Text(t['id'].toString()),
                    ),
                    title: Text(
                      '${t['User']?['username'] ?? 'Unknown'} - ${t['Package']?['name'] ?? 'Package'}',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Recipient: ${t['recipientName']} (${t['recipientPhone']})'),
                        Text('Network: ${t['network']}'),
                        Text('Escrow: ${t['escrowStatus'] ?? 'N/A'}'),
                      ],
                    ),
                    trailing: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TZS ${t['amount']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          t['createdAt']?.substring(0, 10) ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white60
                                : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
        title: const Text('Transactions'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}