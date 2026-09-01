// lib/screens/buyer/buyer_promotions_screen.dart
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

class BuyerPromotionsScreen extends StatefulWidget {
  const BuyerPromotionsScreen({super.key});

  @override
  State<BuyerPromotionsScreen> createState() => _BuyerPromotionsScreenState();
}

class _BuyerPromotionsScreenState extends State<BuyerPromotionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _promotions = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
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
        '${ApiConfig.baseUrl}/api/promotions',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _promotions = data['promotions'] ?? []; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load promotions',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchPromotions);
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

  void _navigateToPackage(dynamic package) {
    if (package == null) return;
    _showBuyDialog(package);
  }

  void _showBuyDialog(dynamic package) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final RegExp _phoneRegex = RegExp(r'^(0|255|\+255)?[67]\d{8}$');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Buy Package'),
        backgroundColor: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Package: ${package['name']}'),
            Text('Price: TZS ${package['displayPrice']}'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Recipient Phone Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                helperText: 'e.g., 0712345678',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
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
            child: const Text('Continue'),
          ),
        ],
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
          title: const Text('Offers & Promotions'),
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
        title: const Text('Offers & Promotions'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _promotions.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active promotions at the moment.',
                style: TextStyle(fontSize: 18)),
            Text(
                'Check back later for offers and discounts.'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchPromotions,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _promotions.length,
          itemBuilder: (ctx, i) {
            final p = _promotions[i];
            final package = p['Package'];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              color: isDark
                  ? Colors.grey.shade800.withValues(alpha: 0.6)
                  : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: package != null
                    ? () => _navigateToPackage(package)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.local_offer,
                                color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p['title'] ?? 'Promotion',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p['description'] ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      if (p['discount'] != null)
                        Chip(
                          label: Text('${p['discount']}% OFF'),
                          backgroundColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          ),
                        ),
                      if (p['validUntil'] != null)
                        Text(
                          'Valid until: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(p['validUntil']))}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                      if (package != null) ...[
                        const Divider(),
                        Text('Package: ${package['name']}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                        Text('Network: ${package['network']}',
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey.shade700)),
                        Text('Data: ${package['dataSize']}',
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey.shade700)),
                        Text('Validity: ${package['validity']}',
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey.shade700)),
                        Text('Price: TZS ${package['displayPrice']}',
                            style: const TextStyle(
                                color: Colors.blue)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () =>
                              _navigateToPackage(package),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF0A2E5C),
                          ),
                          child: const Text('Buy Now',
                              style: TextStyle(
                                  color: Colors.white)),
                        ),
                      ] else
                        Text(
                            'No package associated with this promotion.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            )),
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
}