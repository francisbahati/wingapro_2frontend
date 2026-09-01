// lib/screens/admin/admin_price_management_screen.dart
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
import '../../widgets/error_snackbar.dart';

class AdminPriceManagementScreen extends StatefulWidget {
  const AdminPriceManagementScreen({super.key});

  @override
  State<AdminPriceManagementScreen> createState() =>
      _AdminPriceManagementScreenState();
}

class _AdminPriceManagementScreenState
    extends State<AdminPriceManagementScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _customerPackages = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
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
        '${ApiConfig.baseUrl}/api/admin/packages',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final all = data['packages'] ?? [];
          final customerPkgs = all
              .where((pkg) => pkg['packageType'] == 'customer')
              .toList();
          if (mounted) {
            setState(() {
              _customerPackages = customerPkgs;
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load packages',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPackages);
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

  Future<void> _updatePackagePair(dynamic customerPkg, Map<String, dynamic> updates) async {
    setState(() => _isUpdating = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/packages/pair/${customerPkg['id']}',
        body: updates,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _fetchPackages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Prices updated successfully'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Update failed',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showEditDialog(dynamic customerPkg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController =
    TextEditingController(text: customerPkg['name'] ?? '');
    final customerPriceController =
    TextEditingController(text: customerPkg['price']?.toString() ?? '');
    final sellerPriceController =
    TextEditingController(text: customerPkg['sellerPrice']?.toString() ?? '');
    final dataSizeController =
    TextEditingController(text: customerPkg['dataSize'] ?? '');
    final validityController =
    TextEditingController(text: customerPkg['validity'] ?? '');
    String selectedNetwork = customerPkg['network'] ?? 'Halotel';
    bool isActive = customerPkg['is_active'] ?? true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Edit Prices - ${customerPkg['name']}'),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.15)
                  : Colors.grey.shade300.withValues(alpha: 0.5),
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
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Package Name *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Customer Price (TZS) *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellerPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Seller Price (TZS) *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dataSizeController,
                    decoration: InputDecoration(
                      labelText: 'Data Size (e.g., 10GB) *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: validityController,
                    decoration: InputDecoration(
                      labelText: 'Validity (e.g., 30 days) *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedNetwork,
                    items: ['Halotel', 'Tigo', 'Vodacom', 'Airtel']
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => selectedNetwork = v!),
                    decoration: InputDecoration(
                      labelText: 'Network *',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setStateDialog(() => isActive = v),
                    tileColor: Colors.transparent,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Profit Margin: TZS ${(double.tryParse(customerPriceController.text) ?? 0) - (double.tryParse(sellerPriceController.text) ?? 0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                final name = nameController.text.trim();
                final customerPrice =
                double.tryParse(customerPriceController.text.trim());
                final sellerPrice =
                double.tryParse(sellerPriceController.text.trim());
                final dataSize = dataSizeController.text.trim();
                final validity = validityController.text.trim();
                if (name.isEmpty ||
                    customerPrice == null ||
                    sellerPrice == null ||
                    dataSize.isEmpty ||
                    validity.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'All fields are required and prices must be valid numbers'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (sellerPrice > customerPrice) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Seller price must be less than customer price'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                setStateDialog(() => isSubmitting = true);
                Navigator.pop(ctx);
                await _updatePackagePair(customerPkg, {
                  'name': name,
                  'customerPrice': customerPrice,
                  'sellerPrice': sellerPrice,
                  'dataSize': dataSize,
                  'validity': validity,
                  'network': selectedNetwork,
                  'is_active': isActive,
                });
              },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Price Management'),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPackages),
          ],
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
        title: const Text('Price Management'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPackages),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _customerPackages.isEmpty
          ? const Center(
          child: Text(
              'No customer packages found. Create packages first.'))
          : RefreshIndicator(
        onRefresh: _fetchPackages,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _customerPackages.length,
          itemBuilder: (ctx, i) {
            final p = _customerPackages[i];
            final customerPrice =
                double.tryParse(p['price']?.toString() ?? '0') ??
                    0;
            final sellerPrice = double.tryParse(
                p['sellerPrice']?.toString() ?? '0') ??
                0;
            final profit = customerPrice - sellerPrice;

            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                title: Text(
                  p['name'] ?? 'Package',
                  style: TextStyle(
                      color: isDark ? Colors.white
                          : Colors.black87),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network: ${p['network']} | ${p['dataSize']} | ${p['validity']}',
                      style: TextStyle(
                          color: isDark ? Colors.white70
                              : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('Customer: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
                        Text(
                            'TZS ${customerPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: Colors.green)),
                        const SizedBox(width: 8),
                        Text('Seller: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
                        Text(
                            'TZS ${sellerPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: Colors.blue)),
                        const SizedBox(width: 8),
                        Text('Profit: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
                        Text(
                          'TZS ${profit.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: profit > 0
                                  ? Colors.green
                                  : Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: _isUpdating
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                      : const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _isUpdating
                      ? null
                      : () => _showEditDialog(p),
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