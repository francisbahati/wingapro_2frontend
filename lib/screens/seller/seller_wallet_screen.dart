// lib/screens/seller/seller_wallet_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../payment/payment_deposit_withdraw_screen.dart';

class SellerWalletScreen extends StatefulWidget {
  final bool showAppBar;
  const SellerWalletScreen({super.key, this.showAppBar = true});

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
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
        '${ApiConfig.baseUrl}/api/seller/wallet',
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

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchWalletData();
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
          title: const Text('Wallet'),
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

    Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF0A2E5C),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            backgroundColor: const Color(0xFF0A2E5C).withValues(alpha: 0.95),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
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
              final isCredit = tx['type'] == 'income' ||
                  tx['type'] == 'credit';
              final amount = (tx['amount'] ?? 0.0).toDouble();
              final date = DateTime.tryParse(tx['date'] ?? '');
              final formattedDate = date != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(date)
                  : tx['date'] ?? '';
              return GlassCard(
                backgroundColor: isDark
                    ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.85),
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
                  title: Text(
                    tx['description'] ?? 'Transaction',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                    ),
                  ),
                  trailing: Text(
                    '${isCredit ? '+' : '-'} ${_formatAmount(amount)}',
                    style: TextStyle(
                      color: isCredit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
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
        title: const Text('Wallet'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}