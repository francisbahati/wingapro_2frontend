// lib/screens/admin/admin_sellers_screen.dart
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

class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _sellers = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _searchQuery = '';
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchSellers();
  }

  Future<void> _fetchSellers() async {
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
        '${ApiConfig.baseUrl}/api/admin/sellers',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _sellers = data['sellers'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load sellers',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchSellers);
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

  // ─── Verify Seller Registration Payment ───
  Future<void> _verifyPayment(int sellerId, String sellerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Payment'),
        content: Text('Mark registration payment as verified for $sellerName?'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Verify', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isVerifying = true);
    try {
      final token = await _auth.getToken();
      final response = await _api.put(
        context,
        '${ApiConfig.baseUrl}/api/admin/sellers/$sellerId/verify-payment',
      );
      if (response.statusCode == 200) {
        _fetchSellers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seller registration payment verified'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to verify payment',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  List<dynamic> get _filteredSellers {
    if (_searchQuery.isEmpty) return _sellers;
    final query = _searchQuery.toLowerCase();
    return _sellers.where((seller) {
      final username = (seller['username'] ?? '').toLowerCase();
      final email = (seller['email'] ?? '').toLowerCase();
      final phone = (seller['phone'] ?? '').toLowerCase();
      return username.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  double _parseBalance(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(dynamic value) {
    final parsed = _parseBalance(value);
    return NumberFormat('#,###').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Sellers'),
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
        title: const Text('Sellers'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSellers,
            color: const Color(0xFF0A2E5C),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search sellers by name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.5)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Seller List
          Expanded(
            child: _isLoading
                ? ListView.builder(
              itemCount: 5,
              itemBuilder: (_, __) => const SkeletonListTile(),
            )
                : _filteredSellers.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No sellers found.'),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchSellers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredSellers.length,
                itemBuilder: (ctx, i) {
                  final seller = _filteredSellers[i];
                  final adoptedPackages =
                      seller['adoptedPackages'] as List? ?? [];
                  final balance = _parseBalance(seller['wallet_balance']);
                  final isPaid = seller['seller_registration_paid'] ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      backgroundColor: isDark
                          ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Seller Header
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                const Color(0xFF0A2E5C),
                                child: Text(
                                  (seller['username']?[0] ?? 'S')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seller['username'] ??
                                          'Unknown Seller',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      seller['email'] ?? '',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (seller['phone'] != null &&
                                        seller['phone'].isNotEmpty)
                                      Text(
                                        seller['phone'],
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.red,
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isPaid ? 'Paid' : 'Unpaid',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'TZS ${_formatCurrency(balance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: balance > 0
                                          ? (isDark
                                          ? Colors.green.shade300
                                          : Colors.green)
                                          : (isDark
                                          ? Colors.white54
                                          : Colors.grey.shade500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Adopted Packages Section
                          if (adoptedPackages.isNotEmpty) ...[
                            const Text(
                              'Adopted Packages:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...adoptedPackages.map((pkg) {
                              final p = pkg['Package'] ?? {};
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade50,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wifi,
                                      size: 16,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p['name'] ?? 'Unknown Package',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'TZS ${_formatCurrency(p['price'])}',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      p['network'] ?? '',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      p['dataSize'] ?? '',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: Text(
                                'No packages adopted yet.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // ─── Verify Payment Button (only if unpaid) ───
                          if (!isPaid)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _isVerifying
                                    ? null
                                    : () => _verifyPayment(
                                    seller['id'], seller['username']),
                                icon: _isVerifying
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                                    : const Icon(Icons.verified, size: 18),
                                label: _isVerifying
                                    ? const Text('Verifying...')
                                    : const Text('Verify Payment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}