// lib/screens/buyer/order_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/error_snackbar.dart';
import 'order_confirmation_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final dynamic order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  int _rating = 0;
  bool _isSubmitting = false;

  Future<void> _confirmReceipt() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please rate your experience'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/purchase/${widget.order['id']}/confirm',
        body: {'rating': _rating},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(
              purchaseId: widget.order['id'],
              packageName: widget.order['Package']?['name'] ?? 'Package',
            ),
          ),
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: data['message'] ?? 'Failed to confirm',
        );
      }
    } catch (e) {
      showErrorSnackbar(context, e);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = order['orderStatus'] ?? 'payment_received';
    final canConfirm = status == 'waiting_delivery';
    final packageName = order['Package']?['name'] ?? 'Package';
    final amount = order['amount'] ?? 0;
    final recipientName = order['recipientName'] ?? 'N/A';
    final recipientPhone = order['recipientPhone'] ?? 'N/A';
    final network = order['network'] ?? 'N/A';
    final assignedSeller = order['assignedSeller'];
    final createdAt = order['createdAt'] ?? DateTime.now().toIso8601String();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFF0A2E5C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order['id']}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Package', packageName),
            _buildInfoRow('Recipient', recipientName),
            _buildInfoRow('Phone', recipientPhone),
            _buildInfoRow('Network', network),
            _buildInfoRow('Amount', 'TZS $amount'),
            if (assignedSeller != null)
              _buildInfoRow('Seller', assignedSeller['username']),
            _buildInfoRow('Status', _getStatusText(status)),
            _buildInfoRow('Date', createdAt.substring(0, 10)),
            const Divider(),
            if (canConfirm) ...[
              const Text(
                'Rate your experience:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ),
              const Spacer(),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _confirmReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Confirm Receipt',
                    style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              const Spacer(),
              Center(
                child: Text(
                  _getStatusMessage(status),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'payment_received':
        return 'Payment Received';
      case 'waiting_approval':
        return 'Waiting for Approval';
      case 'approved':
        return 'Approved';
      case 'waiting_delivery':
        return 'Waiting for Delivery';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'payment_received':
        return 'Your payment has been received. An admin will assign a seller shortly.';
      case 'waiting_approval':
        return 'Your order is being reviewed by the admin.';
      case 'approved':
        return 'Your order has been approved. A seller will deliver the package.';
      case 'waiting_delivery':
        return 'The seller has marked your package as delivered. Please confirm receipt and rate the experience.';
      case 'completed':
        return 'This order is complete. Thank you for using WingaPro!';
      default:
        return 'Status: $status';
    }
  }
}