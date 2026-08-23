// lib/screens/business_staff/business_staff_sales_screen.dart
import 'dart:async';
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

class BusinessStaffSalesScreen extends StatefulWidget {
  const BusinessStaffSalesScreen({super.key});

  @override
  State<BusinessStaffSalesScreen> createState() =>
      _BusinessStaffSalesScreenState();
}

class _BusinessStaffSalesScreenState extends State<BusinessStaffSalesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _sales = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSales();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchSales();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSales() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/sales',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _sales = data['sales']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load sales',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchSales);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('My Sales'),
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
        title: const Text('My Sales'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _sales.isEmpty
          ? const Center(
          child: Text('No sales from your customers yet.'))
          : RefreshIndicator(
        onRefresh: _fetchSales,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _sales.length,
          itemBuilder: (ctx, i) {
            final s = _sales[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    s['User']?['username']?[0]?.toUpperCase() ??
                        'U',
                  ),
                ),
                title: Text(
                  '${s['User']?['username']} - ${s['Package']?['name']}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Recipient: ${s['recipientName']} (${s['recipientPhone']})',
                  style: TextStyle(
                    color: isDark ? Colors.white70
                        : Colors.grey.shade700,
                  ),
                ),
                trailing: Text(
                  'TZS ${s['amount']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A2E5C),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}