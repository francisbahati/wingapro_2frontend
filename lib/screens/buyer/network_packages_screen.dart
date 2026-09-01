// lib/screens/buyer/network_packages_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';
import 'payment_screen.dart';

class NetworkPackagesScreen extends StatefulWidget {
  final String network;
  final String? searchQuery;
  final double? minPrice;
  final double? maxPrice;

  const NetworkPackagesScreen({
    super.key,
    this.network = '',
    this.searchQuery,
    this.minPrice,
    this.maxPrice,
  });

  @override
  State<NetworkPackagesScreen> createState() => _NetworkPackagesScreenState();
}

class _NetworkPackagesScreenState extends State<NetworkPackagesScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _allPackages = [];
  List<dynamic> _filteredPackages = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  late AnimationController _animationController;

  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _fetchPackages();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPackages() async {
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
        '${ApiConfig.baseUrl}/api/packages',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final packages = data is List ? data : (data['packages'] ?? []);
        // Filter customer packages only
        _allPackages = packages
            .where((p) => p['packageType'] == 'customer' && p['is_active'] == true)
            .toList();
        _applyFilters();
        if (mounted) setState(() => _isLoading = false);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to load packages',
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

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _fetchPackages();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _applyFilters() {
    var filtered = List.from(_allPackages);

    // Filter by network (if provided)
    if (widget.network.isNotEmpty) {
      filtered = filtered.where((p) => p['network'] == widget.network).toList();
    }

    // Filter by search query (if provided)
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      final query = widget.searchQuery!.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toLowerCase();
        final network = (p['network'] ?? '').toLowerCase();
        final price = _parsePrice(p['price']).toString();
        return name.contains(query) ||
            network.contains(query) ||
            price.contains(query);
      }).toList();
    }

    // Filter by price range
    if (widget.minPrice != null) {
      filtered = filtered.where((p) => _parsePrice(p['price']) >= widget.minPrice!).toList();
    }
    if (widget.maxPrice != null) {
      filtered = filtered.where((p) => _parsePrice(p['price']) <= widget.maxPrice!).toList();
    }

    if (mounted) setState(() => _filteredPackages = filtered);
  }

  void _buyPackage(dynamic package) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final price = _parsePrice(package['price']);
    final displayPrice = NumberFormat('#,###').format(price);
    final RegExp _phoneRegex = RegExp(r'^(0|255|\+255)?[67]\d{8}$');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          title: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Color(0xFF0A2E5C)),
              const SizedBox(width: 8),
              const Text('Confirm Purchase'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package['name'] ?? 'Package',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Data: ${package['dataSize']} • Validity: ${package['validity']}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        'Price: TZS $displayPrice',
                        style: TextStyle(
                            color: const Color(0xFF0A2E5C),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Recipient Name *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade50,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (10 digits) *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.phone),
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade50,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    helperText: 'e.g., 0712345678',
                    helperStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone =
                phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all fields'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                if (!_phoneRegex.hasMatch(phone)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid Tanzanian mobile number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      package: package,
                      selectedNetwork: package['network'] ?? 'Halotel',
                      recipientName: name,
                      recipientPhone: phone,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue',
                  style: TextStyle(color: Colors.white)),
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
          title: Text(
              widget.network.isEmpty ? 'All Packages' : '${widget.network} Packages'),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          elevation: 0,
          centerTitle: true,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
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
        title: Text(
            widget.network.isEmpty ? 'All Packages' : '${widget.network} Packages'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _filteredPackages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.network.isEmpty
                  ? 'No packages available'
                  : 'No packages available for ${widget.network}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text('Check back later for new offers.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0A2E5C),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredPackages.length,
          itemBuilder: (ctx, i) {
            final p = _filteredPackages[i];
            final price = _parsePrice(p['price']);
            return FadeTransition(
              opacity: _animationController.drive(
                  Tween<double>(begin: 0.0, end: 1.0)
                      .chain(CurveTween(curve: Curves.easeOut))),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                color: isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.6)
                    : Colors.white,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p['name'] ?? 'Package',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade200,
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              p['network'] ?? '',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (p['description'] != null &&
                          p['description'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            p['description'],
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.data_usage,
                            label: p['dataSize'] ?? 'N/A',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            icon: Icons.timer,
                            label: p['validity'] ?? 'N/A',
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TZS ${NumberFormat('#,###').format(price)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0A2E5C),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _buyPackage(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF0A2E5C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Buy Now'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}