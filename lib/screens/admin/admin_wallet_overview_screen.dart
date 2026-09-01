// lib/screens/admin/admin_wallet_overview_screen.dart
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

class AdminWalletOverviewScreen extends StatefulWidget {
  const AdminWalletOverviewScreen({super.key});

  @override
  State<AdminWalletOverviewScreen> createState() =>
      _AdminWalletOverviewScreenState();
}

class _AdminWalletOverviewScreenState
    extends State<AdminWalletOverviewScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  double _totalBalance = 0.0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchWalletOverview();
  }

  Future<void> _fetchWalletOverview() async {
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
        '${ApiConfig.baseUrl}/api/admin/wallet-overview',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _users = data['users'] ?? [];
              _totalBalance = (data['totalBalance'] ?? 0.0).toDouble();
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load wallet overview',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchWalletOverview);
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
    await _fetchWalletOverview();
    if (mounted) setState(() => _isRefreshing = false);
  }

  double _parseBalance(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(dynamic value) {
    final parsed = _parseBalance(value);
    return NumberFormat('#,###').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Wallet Overview'),
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
        title: const Text('Wallet Overview'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            color: const Color(0xFF0A2E5C),
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _users.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet,
                size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No users with wallet balances found.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Total Balance Card
            Container(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                backgroundColor: isDark
                    ? const Color(0xFF0A2E5C).withValues(alpha: 0.9)
                    : const Color(0xFF0A2E5C).withValues(alpha: 0.95),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Wallet Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TZS ${_formatCurrency(_totalBalance)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Across ${_users.length} active users',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // User List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final u = _users[i];
                  final balance = _parseBalance(u['wallet_balance']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      backgroundColor: isDark
                          ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          balance > 0 ? Colors.green : Colors.grey,
                          child: Text(
                            u['username'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          u['username'] ?? 'Unknown',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          u['role'] ?? 'customer',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TZS ${_formatCurrency(balance)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: balance > 0
                                    ? (isDark ? Colors.green.shade300 : Colors.green)
                                    : (isDark ? Colors.white54 : Colors.grey.shade500),
                              ),
                            ),
                            if (!u['is_active'])
                              Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}