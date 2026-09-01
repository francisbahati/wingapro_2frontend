// lib/screens/branch_director/branch_director_purchases_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class BranchDirectorPurchasesScreen extends StatefulWidget {
  final bool showAppBar;
  const BranchDirectorPurchasesScreen({super.key, this.showAppBar = true});

  @override
  State<BranchDirectorPurchasesScreen> createState() =>
      _BranchDirectorPurchasesScreenState();
}

class _BranchDirectorPurchasesScreenState
    extends State<BranchDirectorPurchasesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _purchases = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _noBranch = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    if (_isRefreshing) return;
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
      _noBranch = false;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/branch-director/purchases',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _purchases = data['purchases']; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load purchases',
          );
        }
      } else if (response.statusCode == 400) {
        if (mounted) {
          setState(() { _noBranch = true; _isLoading = false; });
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPurchases);
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
    await _fetchPurchases();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_noBranch) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'You are not assigned to any branch.\nPlease contact the administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

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
        : _purchases.isEmpty
        ? const Center(
        child: Text('No purchases from customers in your branch.'))
        : RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _purchases.length,
        itemBuilder: (ctx, i) {
          final p = _purchases[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  p['User']?['username']?[0]?.toUpperCase() ??
                      'U',
                ),
              ),
              title: Text(
                '${p['User']?['username']} - ${p['Package']?['name']}',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Recipient: ${p['recipientName']} (${p['recipientPhone']})',
                style: TextStyle(
                  color: isDark ? Colors.white70
                      : Colors.grey.shade700,
                ),
              ),
              trailing: Text(
                'TZS ${p['amount']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
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
        title: const Text('Purchases'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}