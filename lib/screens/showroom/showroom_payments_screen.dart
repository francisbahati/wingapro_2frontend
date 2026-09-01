// lib/screens/showroom/showroom_payments_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/glass_card.dart'; // ✅ Added missing import

class ShowroomPaymentsScreen extends StatefulWidget {
  const ShowroomPaymentsScreen({super.key});

  @override
  State<ShowroomPaymentsScreen> createState() => _ShowroomPaymentsScreenState();
}

class _ShowroomPaymentsScreenState extends State<ShowroomPaymentsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _purchases = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isConfirming = false;
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
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/showroom/sales',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _purchases = data['sales'] ?? []; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load purchases',
          );
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

  Future<void> _confirmPayment(int purchaseId) async {
    setState(() => _isConfirming = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/showroom/confirm-payment/$purchaseId',
        body: {'status': 'completed'},
      );
      if (response.statusCode == 200) {
        _fetchPurchases();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment confirmed'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to confirm',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Payments'),
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
        title: const Text('Payments'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
          ? const Center(child: Text('No purchases to manage.'))
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _purchases.length,
          itemBuilder: (ctx, i) {
            final p = _purchases[i];
            final isPending = p['status'] == 'pending';
            final isConfirming = _isConfirming;
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                title: Text(
                    'Order #${p['id']} - ${p['User']?['username']}',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Package: ${p['Package']?['name']}'),
                    Text(
                        'Recipient: ${p['recipientName']} (${p['recipientPhone']})'),
                    Text('Network: ${p['network']}'),
                    Text('Status: ${p['status']}'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TZS ${p['amount']}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    if (isPending)
                      ElevatedButton(
                        onPressed: isConfirming
                            ? null
                            : () => _confirmPayment(p['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: isConfirming
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                            : const Text('Confirm Payment'),
                      ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
    );
  }
}