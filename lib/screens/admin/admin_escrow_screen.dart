// lib/screens/admin/admin_escrow_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class AdminEscrowScreen extends StatefulWidget {
  const AdminEscrowScreen({super.key});

  @override
  State<AdminEscrowScreen> createState() => _AdminEscrowScreenState();
}

class _AdminEscrowScreenState extends State<AdminEscrowScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _summary;
  List<dynamic> _pending = [];
  List<dynamic> _released = [];

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

      final summaryRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/escrow-summary',
      );
      final purchasesRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/admin/purchases',
      );

      if (summaryRes.statusCode == 200 && purchasesRes.statusCode == 200) {
        final summaryData = jsonDecode(summaryRes.body);
        final purchasesData = jsonDecode(purchasesRes.body);
        if (summaryData['success'] && purchasesData['success']) {
          final all = purchasesData['purchases'] ?? [];
          if (mounted) {
            setState(() {
              _summary = summaryData;
              _pending = all
                  .where((p) => p['escrowStatus'] == 'paid_to_admin')
                  .toList();
              _released = all
                  .where((p) => p['escrowStatus'] == 'released_to_seller')
                  .toList();
              _isLoading = false;
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
      final info = ErrorHandler.handle(e, onRetry: _fetchData);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Escrow Management'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _fetchData),
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
        title: const Text('Escrow Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _fetchData),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonPurchaseCard(),
      )
          : DefaultTabController(
        length: 2,
        child: Column(
          children: [
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.9),
              child: Column(
                children: [
                  _buildSummaryRow('Total in Escrow',
                      _summary?['totalEscrow'] ?? 0),
                  _buildSummaryRow('Total Released',
                      _summary?['totalReleased'] ?? 0),
                  _buildSummaryRow('Total Admin Profit',
                      _summary?['totalAdminProfit'] ?? 0),
                ],
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: 'Pending (${_pending.length})'),
                Tab(text: 'Released (${_released.length})'),
              ],
              indicatorColor: const Color(0xFF0A2E5C),
              labelColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrderList(_pending, 'pending', isDark),
                  _buildOrderList(_released, 'released', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, String type, bool isDark) {
    if (orders.isEmpty) {
      return Center(
        child: Text(type == 'pending'
            ? 'No pending escrow orders.'
            : 'No released orders yet.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final p = orders[i];
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
                    label: Text(p['orderStatus'] ?? 'pending'),
                    backgroundColor: p['orderStatus'] == 'completed'
                        ? Colors.green
                        : Colors.orange,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Amount: TZS ${p['amount']}'),
              Text('Seller: ${p['assignedSeller']?['username'] ?? 'Not assigned'}'),
              Text('Buyer: ${p['User']?['username'] ?? 'Unknown'}'),
              if (p['rating'] != null) Text('Rating: ${p['rating']} ⭐'),
              if (p['releaseDate'] != null)
                Text('Released: ${p['releaseDate']?.substring(0, 10)}'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, dynamic value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double parsedValue = 0.0;
    if (value != null) {
      if (value is double) parsedValue = value;
      else if (value is int) parsedValue = value.toDouble();
      else if (value is String) parsedValue = double.tryParse(value) ?? 0.0;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          )),
          Text('TZS ${parsedValue.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              )),
        ],
      ),
    );
  }
}