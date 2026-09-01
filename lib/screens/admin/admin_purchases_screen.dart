// lib/screens/admin/admin_purchases_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';
import '../../widgets/error_snackbar.dart';

class AdminPurchasesScreen extends StatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  State<AdminPurchasesScreen> createState() => _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends State<AdminPurchasesScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _purchases = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isAssigning = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterStatus = '';
  String _startDate = '';
  String _endDate = '';
  final Map<int, List<dynamic>> _sellersCache = {};
  final Map<int, int> _assigningIds = {};

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
      String url = '${ApiConfig.baseUrl}/api/admin/purchases';
      final query = [];
      if (_filterStatus.isNotEmpty) query.add('status=$_filterStatus');
      if (_startDate.isNotEmpty && _endDate.isNotEmpty) {
        query.add('startDate=$_startDate');
        query.add('endDate=$_endDate');
      }
      if (query.isNotEmpty) url += '?${query.join('&')}';
      final response = await _api.get(context, url);
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

  Future<List<dynamic>> _getSellersForPackage(int packageId) async {
    if (_sellersCache.containsKey(packageId)) {
      return _sellersCache[packageId]!;
    }
    try {
      final token = await _auth.getToken();
      final response = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/packages/$packageId/sellers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final sellers = data['sellers'] ?? [];
          _sellersCache[packageId] = sellers;
          return sellers;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _assignSeller(int purchaseId, int sellerId) async {
    setState(() {
      _isAssigning = true;
      _assigningIds[purchaseId] = sellerId;
    });
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/purchases/$purchaseId/assign',
        body: {'sellerId': sellerId},
      );
      if (response.statusCode == 200) {
        _fetchPurchases();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller assigned successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to assign',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
          _assigningIds.remove(purchaseId);
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'payment_received': return Colors.blue;
      case 'waiting_approval': return Colors.orange;
      case 'approved': return Colors.purple;
      case 'waiting_delivery': return Colors.teal;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('All Purchases'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPurchases),
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
        title: const Text('All Purchases'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Filter Purchases'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _filterStatus.isEmpty ? null : _filterStatus,
                        hint: const Text('Status'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All')),
                          ...['pending', 'completed', 'failed']
                              .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: 'Start Date (YYYY-MM-DD)'),
                        onChanged: (v) => setState(() => _startDate = v),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: 'End Date (YYYY-MM-DD)'),
                        onChanged: (v) => setState(() => _endDate = v),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _fetchPurchases();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPurchases),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonPurchaseCard(),
      )
          : RefreshIndicator(
        onRefresh: _fetchPurchases,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _purchases.length,
          itemBuilder: (ctx, i) {
            final p = _purchases[i];
            final currentStatus = p['orderStatus'] ?? 'payment_received';
            final assignedSeller = p['assignedSeller'];
            final packageId = p['Package']?['id'];
            final isAssigning = _assigningIds.containsKey(p['id']);

            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${p['id']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          )),
                      Chip(
                        label: Text(
                            currentStatus.replaceAll('_', ' ')),
                        backgroundColor:
                        _getStatusColor(currentStatus),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('User: ${p['User']?['username'] ?? 'User'}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      )),
                  Text(
                      'Package: ${p['Package']?['name'] ?? 'Package'}',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      )),
                  Text(
                      'Recipient: ${p['recipientName']} (${p['recipientPhone']})',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      )),
                  Text('Amount: TZS ${p['amount']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      )),
                  if (assignedSeller != null)
                    Text('Assigned to: ${assignedSeller['username']}',
                        style: const TextStyle(color: Colors.blue)),
                  const SizedBox(height: 8),
                  if (packageId != null)
                    FutureBuilder<List<dynamic>>(
                      future: _getSellersForPackage(packageId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(),
                          );
                        }
                        final sellers = snapshot.data ?? [];
                        if (sellers.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No seller has adopted this package.',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        int? currentSellerId =
                        assignedSeller?['id'] as int?;
                        return DropdownButtonFormField<int>(
                          initialValue: currentSellerId,
                          decoration: const InputDecoration(
                            labelText: 'Assign / Reassign Seller',
                            border: OutlineInputBorder(),
                          ),
                          items: sellers.map((seller) =>
                              DropdownMenuItem<int>(
                                value: seller['id'] as int?,
                                child: Text(seller['username'] ??
                                    'Unknown'),
                              )).toList(),
                          onChanged: isAssigning
                              ? null
                              : (sellerId) {
                            if (sellerId != null) {
                              _assignSeller(p['id'], sellerId);
                            }
                          },
                        );
                      },
                    ),
                  if (p['rating'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Text('Rating: '),
                          ...List.generate(5, (i) => Icon(
                            i < p['rating']
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          )),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}