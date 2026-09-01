// lib/screens/corporate_sales/corporate_sales_cash_purchase_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class CorporateSalesCashPurchaseScreen extends StatefulWidget {
  final bool showAppBar;
  const CorporateSalesCashPurchaseScreen({super.key, this.showAppBar = true});

  @override
  State<CorporateSalesCashPurchaseScreen> createState() =>
      _CorporateSalesCashPurchaseScreenState();
}

class _CorporateSalesCashPurchaseScreenState
    extends State<CorporateSalesCashPurchaseScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();

  List<dynamic> _customers = [];
  List<dynamic> _allPackages = [];

  int? _selectedCustomerId;
  String? _selectedNetwork;
  int? _selectedPackageId;
  String _paymentMethod = 'cash';

  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();

  bool _isLoading = false;
  bool _loadingData = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  final List<String> _networks = ['Halotel', 'Tigo', 'Vodacom', 'Airtel'];
  final RegExp _phoneRegex = RegExp(r'^(0|255|\+255)?[67]\d{8}$');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingData = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final customersRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/corporate-sales/clients',
      );
      final packagesRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/packages',
      );

      if (customersRes.statusCode == 200 && packagesRes.statusCode == 200) {
        final customersData = jsonDecode(customersRes.body);
        final packagesData = jsonDecode(packagesRes.body);

        if (customersData['success'] == true && packagesData['success'] == true) {
          final allPackages = packagesData['packages'] ?? [];
          final customerPackages = allPackages.where((p) => p['packageType'] == 'customer').toList();
          if (mounted) {
            setState(() {
              _customers = customersData['clients'] ?? [];
              _allPackages = customerPackages;
              _loadingData = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: 400,
            message: 'Failed to load data',
          );
        }
      } else {
        throw ApiException(
          statusCode: 500,
          message: 'Server error',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _loadData);
      if (mounted) {
        setState(() {
          _errorTitle = info.title;
          _errorMessage = info.message;
          _retryAction = info.action;
          _loadingData = false;
        });
      }
    }
  }

  List<dynamic> get _filteredPackages {
    if (_selectedNetwork == null || _selectedNetwork!.isEmpty) {
      return [];
    }
    return _allPackages.where((p) => p['network'] == _selectedNetwork).toList();
  }

  Future<void> _submitPurchase() async {
    // Validate
    if (_selectedCustomerId == null) {
      _showSnackBar('Please select a customer', Colors.red);
      return;
    }
    if (_selectedNetwork == null || _selectedNetwork!.isEmpty) {
      _showSnackBar('Please select a network', Colors.red);
      return;
    }
    if (_selectedPackageId == null) {
      _showSnackBar('Please select a package', Colors.red);
      return;
    }
    final name = _recipientNameController.text.trim();
    final phone = _recipientPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('Recipient name and phone are required', Colors.red);
      return;
    }
    if (!_phoneRegex.hasMatch(phone)) {
      _showSnackBar('Enter a valid Tanzanian mobile number (e.g., 0712345678)', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      // Determine endpoint and payload based on payment method
      final bool isCash = _paymentMethod == 'cash';
      final String url = isCash
          ? '${ApiConfig.baseUrl}/api/corporate-sales/cash-purchase'
          : '${ApiConfig.baseUrl}/api/purchase';

      final Map<String, dynamic> body = {
        // For wallet purchases, the backend uses the logged-in user's ID,
        // so we do NOT send customerId.
        if (isCash) 'customerId': _selectedCustomerId,
        'packageId': _selectedPackageId,
        'recipientName': name,
        'recipientPhone': phone,
        'network': _selectedNetwork,
      };

      final response = await _api.post(context, url, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar(
          'Purchase successful! Order #${data['purchase']['id']}',
          Colors.green,
        );
        // Reset form
        setState(() {
          _selectedCustomerId = null;
          _selectedNetwork = null;
          _selectedPackageId = null;
          _recipientNameController.clear();
          _recipientPhoneController.clear();
        });
        await _loadData();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Purchase failed',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingData) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading customers and packages...'),
            ],
          ),
        ),
      );
    }

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: widget.showAppBar
            ? AppBar(
          title: const Text('Sell Package'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        )
            : null,
        body: ErrorView(
          title: _errorTitle!,
          message: _errorMessage!,
          onRetry: _retryAction,
        ),
      );
    }

    Widget body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sell Internet Package',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select customer, network, package, and recipient details.',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Customer dropdown
                DropdownButtonFormField<int>(
                  value: _selectedCustomerId,
                  hint: const Text('Select Customer *'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Customer',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  items: _customers.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['companyName'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedCustomerId = v;
                      _selectedNetwork = null;
                      _selectedPackageId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Network dropdown
                DropdownButtonFormField<String>(
                  value: _selectedNetwork,
                  hint: const Text('Select Network *'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Network',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.network_cell),
                  ),
                  items: _networks.map((n) {
                    return DropdownMenuItem<String>(
                      value: n,
                      child: Text(n),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedNetwork = v;
                      _selectedPackageId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Package dropdown
                DropdownButtonFormField<int>(
                  value: _selectedPackageId,
                  hint: _selectedNetwork == null
                      ? const Text('Select network first')
                      : const Text('Select Package *'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Package',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.wifi),
                  ),
                  items: _filteredPackages.map((p) {
                    final price = p['displayPrice'] ?? p['price'];
                    return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text('${p['name']} - TZS ${price}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedPackageId = v),
                ),
                if (_selectedNetwork != null && _filteredPackages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No packages available for $_selectedNetwork',
                      style: TextStyle(
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                    ),
                  ),
                const SizedBox(height: 16),

                // Recipient name
                TextField(
                  controller: _recipientNameController,
                  decoration: InputDecoration(
                    labelText: 'Recipient Name *',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // Recipient phone
                TextField(
                  controller: _recipientPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Recipient Phone *',
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.phone),
                    hintText: 'e.g., 0712345678',
                  ),
                ),
                const SizedBox(height: 16),

                // Payment method toggle
                const Text('Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Cash'),
                        value: 'cash',
                        groupValue: _paymentMethod,
                        onChanged: (v) => setState(() => _paymentMethod = v!),
                        tileColor: Colors.transparent,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Wallet'),
                        value: 'wallet',
                        groupValue: _paymentMethod,
                        onChanged: (v) => setState(() => _paymentMethod = v!),
                        tileColor: Colors.transparent,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _submitPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _paymentMethod == 'cash'
                        ? 'Sell for Cash'
                        : 'Sell from Wallet',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
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
        title: const Text('Sell Package'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}