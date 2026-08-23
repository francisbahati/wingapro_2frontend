// lib/screens/admin/admin_promotions_screen.dart
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

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _promotions = [];
  List<dynamic> _packages = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final promoRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/promotions',
      );
      final packageRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/packages',
      );
      if (promoRes.statusCode == 200 && packageRes.statusCode == 200) {
        final promoData = jsonDecode(promoRes.body);
        final packageData = jsonDecode(packageRes.body);
        if (promoData['success'] && packageData['success']) {
          final allPkgs = packageData['packages'] ?? [];
          final customerPkgs = allPkgs
              .where((p) => p['packageType'] == 'customer')
              .toList();
          setState(() {
            _promotions = promoData['promotions'] ?? [];
            _packages = customerPkgs;
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: 400,
            message: promoData['message'] ??
                packageData['message'] ??
                'Failed to load data',
          );
        }
      } else {
        throw ApiException(
          statusCode: 500,
          message: 'Server error: ${promoRes.statusCode} / ${packageRes.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchData);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePromotion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promotion'),
        content: const Text('Are you sure?'),
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
        '${ApiConfig.baseUrl}/api/admin/promotions/$id',
      );
      if (response.statusCode == 200) {
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promotion deleted'), backgroundColor: Colors.green),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to delete',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    }
  }

  void _showAddEditDialog({dynamic promotion}) {
    final isEditing = promotion != null;
    final titleController =
    TextEditingController(text: isEditing ? promotion['title'] : '');
    final descController =
    TextEditingController(text: isEditing ? promotion['description'] : '');
    final discountController = TextEditingController(
        text: isEditing ? promotion['discount']?.toString() : '');
    final validUntilController = TextEditingController(
        text: isEditing && promotion['validUntil'] != null
            ? promotion['validUntil'].substring(0, 10)
            : '');
    int? selectedPackageId = isEditing ? promotion['packageId'] : null;
    bool isActive = isEditing ? promotion['is_active'] : true;
    bool isSubmitting = false;

    Map<String, dynamic>? selectedPackageDetails;
    if (selectedPackageId != null) {
      selectedPackageDetails = _packages.firstWhere(
              (p) => p['id'] == selectedPackageId,
          orElse: () => null);
    }

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEditing ? 'Edit Promotion' : 'Add Promotion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *')),
                TextField(controller: descController,
                    decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Discount % *')),
                DropdownButtonFormField<int>(
                  value: selectedPackageId,
                  hint: const Text('Select Customer Package (optional)'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('None')),
                    ..._packages.map((p) {
                      final label =
                          '${p['name']} - ${p['dataSize']} - ${p['network']} (TZS ${p['price']})';
                      return DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(label),
                      );
                    }).toList(),
                  ],
                  onChanged: (v) {
                    setStateDialog(() {
                      selectedPackageId = v;
                      if (v != null) {
                        selectedPackageDetails = _packages.firstWhere(
                                (p) => p['id'] == v,
                            orElse: () => null);
                      } else {
                        selectedPackageDetails = null;
                      }
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Package'),
                ),
                if (selectedPackageDetails != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Network: ${selectedPackageDetails?['network'] ?? 'N/A'}'),
                        Text(
                            'Data Size: ${selectedPackageDetails?['dataSize'] ?? 'N/A'}'),
                        Text(
                            'Validity: ${selectedPackageDetails?['validity'] ?? 'N/A'}'),
                        Text(
                            'Customer Price: TZS ${selectedPackageDetails?['price'] ?? 'N/A'}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(controller: validUntilController,
                    decoration: const InputDecoration(
                        labelText: 'Valid Until (YYYY-MM-DD)')),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setStateDialog(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                final title = titleController.text.trim();
                final discountStr = discountController.text.trim();
                if (title.isEmpty || discountStr.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Title and discount are required'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                final discount = int.tryParse(discountStr);
                if (discount == null || discount < 0 || discount > 100) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Discount must be between 0 and 100'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                final validUntil = validUntilController.text.trim()
                    .isNotEmpty
                    ? validUntilController.text.trim()
                    : null;
                setStateDialog(() => isSubmitting = true);
                try {
                  final token = await _auth.getToken();
                  final body = {
                    'title': title,
                    'description': descController.text.trim(),
                    'discount': discount,
                    'packageId': selectedPackageId,
                    'validUntil': validUntil,
                    'is_active': isActive,
                  };
                  final url = isEditing
                      ? '${ApiConfig.baseUrl}/api/admin/promotions/${promotion['id']}'
                      : '${ApiConfig.baseUrl}/api/admin/promotions';
                  dynamic response;
                  if (isEditing) {
                    response = await _api.put(ctx, url, body: body);
                  } else {
                    response = await _api.post(ctx, url, body: body);
                  }
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 200 ||
                      response.statusCode == 201) {
                    if (data['success'] == true) {
                      Navigator.pop(ctx);
                      _fetchData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isEditing
                                ? 'Promotion updated'
                                : 'Promotion created'),
                            backgroundColor: Colors.green),
                      );
                    } else {
                      throw ApiException(
                        statusCode: response.statusCode,
                        message: data['message'] ?? 'Unknown error',
                      );
                    }
                  } else {
                    throw ApiException(
                      statusCode: response.statusCode,
                      message: data['message'] ??
                          'Server error: ${response.statusCode}',
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
                  : Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorTitle != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Promotions'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.add),
                onPressed: () => _showAddEditDialog()),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
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
      appBar: AppBar(
        title: const Text('Manage Promotions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add),
              onPressed: () => _showAddEditDialog()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _promotions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No promotions created yet.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showAddEditDialog(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5C)),
              child: const Text('Add Promotion'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _promotions.length,
          itemBuilder: (ctx, i) {
            final p = _promotions[i];
            final package = p['Package'];
            return GlassCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                  p['is_active'] ? Colors.green : Colors.red,
                  child: const Icon(Icons.local_offer,
                      color: Colors.white),
                ),
                title: Text(p['title']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['description'] ?? ''),
                    Text('Discount: ${p['discount']}%'),
                    if (p['validUntil'] != null)
                      Text(
                          'Valid until: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(p['validUntil']))}'),
                    if (package != null)
                      Text(
                          'Package: ${package['name']} - ${package['dataSize']} - ${package['network']}'),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blue),
                      onPressed: () =>
                          _showAddEditDialog(promotion: p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red),
                      onPressed: () =>
                          _deletePromotion(p['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}