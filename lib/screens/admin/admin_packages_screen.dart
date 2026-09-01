// lib/screens/admin/admin_packages_screen.dart
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

class AdminPackagesScreen extends StatefulWidget {
  final bool showAppBar;
  final TextEditingController? searchController;
  final String? filterType;

  const AdminPackagesScreen({
    super.key,
    this.showAppBar = true,
    this.searchController,
    this.filterType,
  });

  @override
  State<AdminPackagesScreen> createState() => _AdminPackagesScreenState();
}

class _AdminPackagesScreenState extends State<AdminPackagesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _allPackages = [];
  List<dynamic> _filteredPackages = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterType = 'all';
  String _searchQuery = '';
  late TextEditingController _searchController;

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
    _searchController = widget.searchController ?? TextEditingController();
    _filterType = widget.filterType ?? 'all';

    _fetchPackages();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
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
          if (mounted) {
            setState(() {
              _allPackages = data['packages'] ?? [];
              _applyFilter();
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

  void _applyFilter() {
    final query = _searchQuery.toLowerCase();
    List<dynamic> filtered = List.from(_allPackages);
    if (_filterType != 'all') {
      filtered = filtered.where((p) => p['packageType'] == _filterType).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }
    if (mounted) setState(() => _filteredPackages = filtered);
  }

  String _formatPrice(dynamic value) {
    final price = _parsePrice(value);
    return NumberFormat('#,###').format(price);
  }

  Future<void> _addOrEditPackage([dynamic existing]) async {
    final isEdit = existing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: isEdit ? existing['name'] : '');
    final descController = TextEditingController(
        text: isEdit ? existing['description'] ?? '' : '');
    final priceController = TextEditingController(
      text: isEdit ? _formatPrice(existing['price']) : '',
    );
    final sellerPriceController = TextEditingController(
      text: isEdit && existing['sellerPrice'] != null
          ? _formatPrice(existing['sellerPrice'])
          : '',
    );

    String dataSizeValue = '';
    String dataSizeUnit = 'GB';
    if (isEdit && existing['dataSize'] != null) {
      final parts = existing['dataSize'].toString().split(' ');
      if (parts.length == 2) {
        dataSizeValue = parts[0];
        dataSizeUnit = parts[1];
      } else if (parts.length == 1 && parts[0].toLowerCase() == 'unlimited') {
        dataSizeValue = 'unlimited';
        dataSizeUnit = 'Unlimited';
      }
    }

    String validityValue = '';
    String validityUnit = 'Days';
    if (isEdit && existing['validity'] != null) {
      final parts = existing['validity'].toString().split(' ');
      if (parts.length == 2) {
        validityValue = parts[0];
        validityUnit = parts[1];
      } else if (parts.length == 1 && parts[0].toLowerCase() == 'notimelimit') {
        validityValue = 'unlimited';
        validityUnit = 'No Time Limit';
      }
    }

    String selectedNetwork = isEdit ? existing['network'] : 'Halotel';
    bool isActive = isEdit ? existing['is_active'] : true;
    bool isSubmitting = false;

    final dataSizeUnits = ['GB', 'MB', 'Unlimited'];
    final validityUnits = ['Days', 'Hours', 'Months', 'Years', 'No Time Limit'];

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Package' : 'Add New Package'),
          backgroundColor: isDark
              ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isEdit)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Creating a new package will generate both Customer and Seller versions.',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
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
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(),
                    decoration: InputDecoration(
                      labelText: 'Customer Price (TZS) *',
                      prefixText: 'TZS ',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      final raw = v.replaceAll(RegExp(r'[^\d]'), '');
                      if (raw.isNotEmpty) {
                        final formatted =
                        NumberFormat('#,###').format(int.parse(raw));
                        priceController.value = TextEditingValue(
                          text: formatted,
                          selection:
                          TextSelection.collapsed(offset: formatted.length),
                        );
                      } else {
                        priceController.value =
                        const TextEditingValue(text: '');
                      }
                    },
                  ),
                  if (!isEdit || (isEdit && existing['packageType'] == 'customer'))
                    const SizedBox(height: 12),
                  if (!isEdit || (isEdit && existing['packageType'] == 'customer'))
                    TextField(
                      controller: sellerPriceController,
                      keyboardType: const TextInputType.numberWithOptions(),
                      decoration: InputDecoration(
                        labelText: 'Seller Price (TZS) *',
                        prefixText: 'TZS ',
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800.withValues(alpha: 0.5)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        final raw = v.replaceAll(RegExp(r'[^\d]'), '');
                        if (raw.isNotEmpty) {
                          final formatted =
                          NumberFormat('#,###').format(int.parse(raw));
                          sellerPriceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        } else {
                          sellerPriceController.value =
                          const TextEditingValue(text: '');
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: TextEditingController(text: dataSizeValue),
                          decoration: InputDecoration(
                            labelText: 'Data Size',
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800.withValues(alpha: 0.5)
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => dataSizeValue = v,
                          keyboardType: const TextInputType.numberWithOptions(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: dataSizeUnit,
                          items: dataSizeUnits.map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => dataSizeUnit = v!),
                          decoration: InputDecoration(
                            labelText: 'Unit',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: TextEditingController(text: validityValue),
                          decoration: InputDecoration(
                            labelText: 'Validity',
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800.withValues(alpha: 0.5)
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) => validityValue = v,
                          keyboardType: const TextInputType.numberWithOptions(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: validityUnit,
                          items: validityUnits.map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => validityUnit = v!),
                          decoration: InputDecoration(
                            labelText: 'Unit',
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
                      ),
                    ],
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
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final dataSize = dataSizeValue.trim().isEmpty
                    ? '0'
                    : dataSizeValue.trim();
                final dataSizeStr = dataSizeUnit == 'Unlimited'
                    ? 'Unlimited'
                    : '$dataSize $dataSizeUnit';
                final validity = validityValue.trim().isEmpty
                    ? '0'
                    : validityValue.trim();
                final validityStr = validityUnit == 'No Time Limit'
                    ? 'No Time Limit'
                    : '$validity $validityUnit';

                final priceRaw =
                priceController.text.replaceAll(RegExp(r'[^\d]'), '');
                final sellerPriceRaw = sellerPriceController.text
                    .replaceAll(RegExp(r'[^\d]'), '');

                if (name.isEmpty || priceRaw.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Name and Customer Price are required'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                final double? priceNum = double.tryParse(priceRaw);
                if (priceNum == null || priceNum <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Invalid customer price'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                final double? sellerPriceNum = sellerPriceRaw.isNotEmpty
                    ? double.tryParse(sellerPriceRaw)
                    : null;
                if (sellerPriceRaw.isNotEmpty &&
                    (sellerPriceNum == null || sellerPriceNum <= 0)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Invalid seller price'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                setStateDialog(() => isSubmitting = true);
                try {
                  final token = await _auth.getToken();
                  final url =
                      '${ApiConfig.baseUrl}/api/admin/packages${isEdit ? '/${existing['id']}' : ''}';
                  final Map<String, dynamic> body = {
                    'name': name,
                    'description': desc,
                    'dataSize': dataSizeStr,
                    'validity': validityStr,
                    'network': selectedNetwork,
                    'is_active': isActive,
                  };

                  if (isEdit) {
                    body['price'] = priceNum;
                    if (existing['packageType'] == 'customer') {
                      body['sellerPrice'] = sellerPriceNum;
                    } else {
                      body['sellerPrice'] = null;
                    }
                    body['packageType'] = existing['packageType'];
                  } else {
                    if (sellerPriceNum == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Seller price is required for new package'),
                            backgroundColor: Colors.red),
                      );
                      setStateDialog(() => isSubmitting = false);
                      return;
                    }
                    body['price'] = priceNum;
                    body['sellerPrice'] = sellerPriceNum;
                  }

                  dynamic response;
                  if (isEdit) {
                    response = await _api.put(ctx, url, body: body);
                  } else {
                    response = await _api.post(ctx, url, body: body);
                  }

                  final data = jsonDecode(response.body);
                  if (response.statusCode == 201 ||
                      response.statusCode == 200) {
                    if (data['success'] == true) {
                      Navigator.pop(ctx);
                      _fetchPackages();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(isEdit
                                  ? 'Package updated'
                                  : 'Package pair created'),
                              backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      throw ApiException(
                        statusCode: response.statusCode,
                        message: data['message'] ?? 'Operation failed',
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: 'Server error: ${response.statusCode}',
                    );
                  }
                } catch (e) {
                  if (mounted) showErrorSnackbar(ctx, e);
                  setStateDialog(() => isSubmitting = false);
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Update' : 'Create Pair'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(int id, bool current) async {
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/packages/$id',
        body: {'is_active': !current},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPackages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(!current ? 'Package activated' : 'Package deactivated'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _deletePackage(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package'),
        content: const Text('Are you sure you want to delete this package?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final token = await _auth.getToken();
      final response = await _api.delete(
        context,
        '${ApiConfig.baseUrl}/api/admin/packages/$id',
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchPackages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Package deleted'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final packages = _filteredPackages;

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
        : packages.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No packages found.'),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchPackages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: packages.length,
        itemBuilder: (ctx, i) {
          final p = packages[i];
          final isCustomer = p['packageType'] == 'customer';
          final price = _parsePrice(p['price']);
          final sellerPrice = _parsePrice(p['sellerPrice']);
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            p['name'] ?? 'Untitled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(isCustomer ? 'Customer' : 'Seller'),
                            backgroundColor: isCustomer ? Colors.blue : Colors.orange,
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(p['is_active'] ? 'Active' : 'Inactive'),
                      backgroundColor: p['is_active'] ? Colors.green : Colors.red,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (p['description'] != null && p['description'].isNotEmpty)
                  Text(
                    p['description'],
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                  ),
                const SizedBox(height: 8),
                Text(
                  isCustomer
                      ? 'Price: TZS ${NumberFormat('#,###').format(price)}'
                      : 'Seller Price: TZS ${NumberFormat('#,###').format(price)}',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                if (isCustomer && p['sellerPrice'] != null)
                  Text(
                    'Seller Price: TZS ${NumberFormat('#,###').format(sellerPrice)}',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                  ),
                Text(
                  'Data Size: ${p['dataSize']}',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                Text(
                  'Validity: ${p['validity']}',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                Text(
                  'Network: ${p['network']}',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addOrEditPackage(p),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleActive(p['id'], p['is_active']),
                        icon: Icon(p['is_active'] ? Icons.pause : Icons.play_arrow, size: 18),
                        label: Text(p['is_active'] ? 'Deactivate' : 'Activate'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deletePackage(p['id']),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
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
        title: const Text('Manage Packages'),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addOrEditPackage()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPackages),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search packages...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'customer', child: Text('Customer')),
                      DropdownMenuItem(value: 'seller', child: Text('Seller')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterType = value!;
                        _applyFilter();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}