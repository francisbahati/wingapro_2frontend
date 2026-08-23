// lib/screens/seller/seller_orders_screen.dart
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

class SellerOrdersScreen extends StatefulWidget {
  final bool showAppBar;
  const SellerOrdersScreen({super.key, this.showAppBar = true});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
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
        '${ApiConfig.baseUrl}/api/seller/assigned-orders',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _orders = data['orders'] ?? []; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load orders',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchOrders);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _markDelivered(int orderId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/seller/orders/$orderId/deliver',
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as delivered!'), backgroundColor: Colors.green),
        );
        _fetchOrders();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to update',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectOrder(int orderId) async {
    if (_isProcessing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Order'),
        content: const Text(
            'Are you sure you want to reject this order? It will be unassigned and available for other sellers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/seller/orders/$orderId/reject',
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order rejected and unassigned.'), backgroundColor: Colors.orange),
        );
        _fetchOrders();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to reject order',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'payment_received':
        return Colors.blue;
      case 'waiting_approval':
        return Colors.orange;
      case 'approved':
        return Colors.purple;
      case 'waiting_delivery':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      itemCount: 4,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : _orders.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64,
              color: Colors.grey),
          SizedBox(height: 16),
          Text('No orders assigned to you yet.'),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (ctx, i) {
          final order = _orders[i];
          final isActionable = order['orderStatus'] !=
              'waiting_delivery' &&
              order['orderStatus'] != 'completed';
          final earning = double.tryParse(
              order['sellerAmount']?.toString() ?? '') ??
              0.0;
          return GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order['id']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      Chip(
                        label: Text(
                          order['orderStatus']?.replaceAll('_',
                              ' ') ??
                              'pending',
                          style: const TextStyle(
                              color: Colors.white),
                        ),
                        backgroundColor: _getStatusColor(
                            order['orderStatus']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Package: ${order['Package']?['name'] ?? 'N/A'}',
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Buyer: ${order['User']?['username'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Recipient: ${order['recipientName']} (${order['recipientPhone']})',
                    style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Your earning: TZS ${earning.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isActionable)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _markDelivered(
                                order['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Text('Deliver'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _rejectOrder(
                                order['id']),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(
                                  color: Colors.red),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
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
        title: const Text('My Orders'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}