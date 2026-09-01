// lib/screens/buyer/buyer_wallet_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/error_view.dart';
import '../../models/withdrawal_model.dart';
import '../payment/payment_deposit_withdraw_screen.dart';

class BuyerWalletScreen extends StatefulWidget {
  const BuyerWalletScreen({super.key});

  @override
  State<BuyerWalletScreen> createState() => _BuyerWalletScreenState();
}

class _BuyerWalletScreenState extends State<BuyerWalletScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  List<WithdrawalRequest> _withdrawals = [];
  bool _isLoading = true;
  bool _isLoadingWithdrawals = false;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
    _fetchWithdrawalHistory();
  }

  Future<void> _fetchWalletData() async {
    if (_isRefreshing) return;
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
        '${ApiConfig.baseUrl}/api/wallet',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _balance = (data['balance'] ?? 0.0).toDouble();
              _transactions = data['transactions'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load wallet',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchWalletData);
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

  Future<void> _fetchWithdrawalHistory() async {
    setState(() => _isLoadingWithdrawals = true);
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      final response = await _api.getWithdrawalHistory(context, limit: 10);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['withdrawals'] as List? ?? [];
          if (mounted) {
            setState(() {
              _withdrawals = list.map((json) => WithdrawalRequest.fromJson(json)).toList();
              _isLoadingWithdrawals = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingWithdrawals = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingWithdrawals = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWithdrawals = false);
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchWalletData();
    await _fetchWithdrawalHistory();
    if (mounted) setState(() => _isRefreshing = false);
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: 'TZS ',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('My Wallet'),
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
        title: const Text('My Wallet'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A2E5C), Color(0xFF1A3A7A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Balance',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatAmount(_balance),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRefreshing
                            ? null
                            : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const PaymentDepositWithdrawScreen(
                                allowWithdraw: true,
                              ),
                            ),
                          );
                          await _refreshData();
                        },
                        icon: _isRefreshing
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A2E5C)),
                        )
                            : const Icon(Icons.payment),
                        label: _isRefreshing
                            ? const Text('Loading...')
                            : const Text('Deposit / Withdraw'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0A2E5C),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal History Section
            Text(
              'Withdrawal History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingWithdrawals)
              const Center(child: CircularProgressIndicator())
            else if (_withdrawals.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No withdrawal requests yet.'),
                ),
              )
            else
              ..._withdrawals.map((w) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: w.status.color,
                    child: Icon(
                      w.status == WithdrawalStatus.completed
                          ? Icons.check
                          : w.status == WithdrawalStatus.rejected
                          ? Icons.close
                          : Icons.hourglass_empty,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text('TZS ${w.amount.toStringAsFixed(0)}'),
                  subtitle: Text(
                    '${w.status.displayName} • ${DateFormat('dd/MM/yy').format(w.requestedAt)}',
                  ),
                  trailing: Text(
                    w.status == WithdrawalStatus.completed
                        ? '✅ Sent'
                        : w.status == WithdrawalStatus.rejected
                        ? '❌ Rejected'
                        : '⏳ Pending',
                    style: TextStyle(
                      color: w.status.color,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              )),
            const Divider(),
            const SizedBox(height: 8),

            // Recent Transactions
            const Text(
              'Recent Transactions',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No transactions yet.'),
                ),
              )
            else
              ..._transactions.map((tx) {
                final isCredit = tx['type'] == 'credit';
                final amount = (tx['amount'] ?? 0.0).toDouble();
                final date = DateTime.tryParse(tx['date'] ?? '');
                final formattedDate = date != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(date)
                    : tx['date'] ?? '';
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCredit
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        isCredit
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(tx['description'] ?? 'Transaction'),
                    subtitle: Text(formattedDate),
                    trailing: Text(
                      '${isCredit ? '+' : '-'} ${_formatAmount(amount)}',
                      style: TextStyle(
                        color: isCredit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}