// lib/screens/business_staff/business_staff_customers_screen.dart
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

class BusinessStaffCustomersScreen extends StatefulWidget {
  const BusinessStaffCustomersScreen({super.key});

  @override
  State<BusinessStaffCustomersScreen> createState() =>
      _BusinessStaffCustomersScreenState();
}

class _BusinessStaffCustomersScreenState
    extends State<BusinessStaffCustomersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _customers = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/customers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _customers = data['customers'] ?? [];
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load customers',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchCustomers);
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
          title: const Text('My Customers'),
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
        title: const Text('My Customers'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCustomers,
            color: const Color(0xFF0A2E5C),
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _customers.isEmpty
          ? const Center(child: Text('No customers found.'))
          : RefreshIndicator(
        onRefresh: _fetchCustomers,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _customers.length,
          itemBuilder: (ctx, i) {
            final c = _customers[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0A2E5C),
                  child: Text(
                    c['username'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  c['username'],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${c['email']} | ${c['phone'] ?? 'No phone'}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
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