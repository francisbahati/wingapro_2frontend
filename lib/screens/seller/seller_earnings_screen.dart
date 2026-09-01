// lib/screens/seller/seller_earnings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});

  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  double _totalEarned = 0.0;
  double _pendingEscrow = 0.0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
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
        '${ApiConfig.baseUrl}/api/seller/earnings',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _totalEarned = (data['totalEarned'] ?? 0.0).toDouble();
              _pendingEscrow = (data['pendingEscrow'] ?? 0.0).toDouble();
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load earnings',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchEarnings);
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
    await _fetchEarnings();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('My Earnings'),
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
        title: const Text('My Earnings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.green.shade50.withValues(alpha: 0.9),
              child: Column(
                children: [
                  const Text(
                    'Total Earned',
                    style: TextStyle(
                        fontSize: 16, color: Colors.green),
                  ),
                  Text(
                    'TZS ${_totalEarned.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.green.shade300 : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.orange.shade50.withValues(alpha: 0.9),
              child: Column(
                children: [
                  const Text(
                    'Pending Escrow',
                    style: TextStyle(
                        fontSize: 16, color: Colors.orange),
                  ),
                  Text(
                    'TZS ${_pendingEscrow.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.orange.shade300 : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.85),
              child: Column(
                children: [
                  const Text(
                    'Earnings Breakdown',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildBreakdownRow('Total Completed Orders',
                      'TZS ${_totalEarned.toStringAsFixed(0)}'),
                  _buildBreakdownRow('Pending Release',
                      'TZS ${_pendingEscrow.toStringAsFixed(0)}'),
                  const Divider(),
                  _buildBreakdownRow(
                    'Total Gross',
                    'TZS ${(_totalEarned + _pendingEscrow).toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isTotal = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}