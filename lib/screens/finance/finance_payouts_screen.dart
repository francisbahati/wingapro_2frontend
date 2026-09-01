// lib/screens/finance/finance_payouts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class FinancePayoutsScreen extends StatefulWidget {
  final bool showAppBar;
  const FinancePayoutsScreen({super.key, this.showAppBar = true});

  @override
  State<FinancePayoutsScreen> createState() => _FinancePayoutsScreenState();
}

class _FinancePayoutsScreenState extends State<FinancePayoutsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _released = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchPayouts();
  }

  Future<void> _fetchPayouts() async {
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
        '${ApiConfig.baseUrl}/api/finance/payouts',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              // Only keep released payouts (read‑only)
              _released = data['released'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load payouts',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPayouts);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      itemCount: 4,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : _released.isEmpty
        ? const Center(child: Text('No released payouts yet.'))
        : RefreshIndicator(
      onRefresh: _fetchPayouts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _released.length,
        itemBuilder: (ctx, i) {
          final p = _released[i];
          final seller = p['assignedSeller'];
          final buyer = p['User'];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${p['id']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Chip(
                      label: const Text('Released'),
                      backgroundColor: Colors.green,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Seller: ${seller?['username'] ?? 'Not assigned'}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Buyer: ${buyer?['username'] ?? 'Unknown'}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Amount: TZS ${p['sellerAmount'] ?? p['amount']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (p['releaseDate'] != null)
                  Text(
                    'Released: ${p['releaseDate']?.substring(0, 10)}',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                    ),
                  ),
              ],
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
        title: const Text('Released Payouts'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}