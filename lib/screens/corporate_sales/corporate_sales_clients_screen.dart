// lib/screens/corporate_sales/corporate_sales_clients_screen.dart
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
import '../../widgets/error_snackbar.dart';

class CorporateSalesClientsScreen extends StatefulWidget {
  final bool showAppBar;
  const CorporateSalesClientsScreen({super.key, this.showAppBar = true});

  @override
  State<CorporateSalesClientsScreen> createState() =>
      _CorporateSalesClientsScreenState();
}

class _CorporateSalesClientsScreenState
    extends State<CorporateSalesClientsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _clients = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Timer? _refreshTimer;
  String _filterStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchClients();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      String url = '${ApiConfig.baseUrl}/api/corporate-sales/clients';
      if (_filterStatus.isNotEmpty) url += '?status=$_filterStatus';
      final response = await _api.get(context, url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _clients = data['clients']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load clients',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchClients);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _addClient() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final companyController = TextEditingController();
    final contactController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final industryController = TextEditingController();
    final addressController = TextEditingController();
    String selectedStatus = 'pending';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Corporate Client'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.15)
                  : Colors.grey.shade300.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: companyController,
                    decoration: InputDecoration(
                      labelText: 'Company Name *',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Contact Person *',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone *',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: industryController,
                    decoration: InputDecoration(
                      labelText: 'Industry',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: ['pending', 'active', 'inactive']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedStatus = v!),
                    decoration: InputDecoration(
                      labelText: 'Status',
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                final company = companyController.text.trim();
                final contact = contactController.text.trim();
                final email = emailController.text.trim();
                final phone = phoneController.text.trim();
                if (company.isEmpty ||
                    contact.isEmpty ||
                    email.isEmpty ||
                    phone.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Fill all required fields'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => isSubmitting = true);
                try {
                  final token = await _auth.getToken();
                  final response = await _api.post(
                    ctx,
                    '${ApiConfig.baseUrl}/api/corporate-sales/clients',
                    body: {
                      'companyName': company,
                      'contactPerson': contact,
                      'email': email,
                      'phone': phone,
                      'industry': industryController.text.trim(),
                      'address': addressController.text.trim(),
                      'status': selectedStatus,
                    },
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 &&
                      data['success'] == true) {
                    Navigator.pop(ctx);
                    _fetchClients();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Client added'),
                          backgroundColor: Colors.green),
                    );
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ?? 'Failed to add',
                    );
                  }
                } catch (e) {
                  showErrorSnackbar(ctx, e);
                  setStateDialog(() => isSubmitting = false);
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
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
        : _clients.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No corporate clients yet.'),
          SizedBox(height: 8),
          Text('Tap + to add a client.'),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchClients,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clients.length,
        itemBuilder: (ctx, i) {
          final c = _clients[i];
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(c['status']),
                child: Text(
                  c['companyName']?[0]?.toUpperCase() ?? 'C',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                c['companyName'],
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact: ${c['contactPerson']}'),
                  Text('Email: ${c['email']} | Phone: ${c['phone']}'),
                ],
              ),
              trailing: Chip(
                label: Text(c['status'] ?? 'pending'),
                backgroundColor: _getStatusColor(c['status']),
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        floatingActionButton: FloatingActionButton(
          onPressed: _addClient,
          backgroundColor: const Color(0xFF0A2E5C),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Corporate Clients'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClient,
        backgroundColor: const Color(0xFF0A2E5C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: body,
    );
  }
}