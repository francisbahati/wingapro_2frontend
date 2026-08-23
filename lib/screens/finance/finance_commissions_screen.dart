// lib/screens/finance/finance_commissions_screen.dart
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

class FinanceCommissionsScreen extends StatefulWidget {
  final bool showAppBar;
  const FinanceCommissionsScreen({super.key, this.showAppBar = true});

  @override
  State<FinanceCommissionsScreen> createState() =>
      _FinanceCommissionsScreenState();
}

class _FinanceCommissionsScreenState extends State<FinanceCommissionsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  double _totalCommission = 0;
  List<dynamic> _commissions = [];
  Map<String, dynamic>? _targets;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchCommissions();
  }

  Future<void> _fetchCommissions() async {
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
        '${ApiConfig.baseUrl}/api/finance/commissions',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _totalCommission = data['totalCommission']?.toDouble() ?? 0;
            _commissions = data['commissionsByPackage'] ?? [];
            _targets = data['targets'];
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load commissions',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchCommissions);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Widget _buildTargetItem(String label, int value, IconData icon, [Color? color]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 100, color: Colors.grey),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(4, (_) => Column(
                      children: [
                        Icon(Icons.circle, color: Colors.grey, size: 28),
                        const SizedBox(height: 4),
                        Container(height: 20, width: 40,
                            color: Colors.grey),
                        Container(height: 12, width: 60,
                            color: Colors.grey),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              child: Column(
                children: [
                  Container(height: 16, width: 120, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 28, width: 150, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Commission by Package',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(3, (_) => const SkeletonListTile()),
      ],
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : RefreshIndicator(
      onRefresh: _fetchCommissions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_targets != null)
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.95)
                  : Colors.blue.shade50.withOpacity(0.9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Targets',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTargetItem('Total Customers',
                          _targets?['totalCustomers'] ?? 0, Icons.people),
                      _buildTargetItem('Filled',
                          _targets?['filledCustomers'] ?? 0,
                          Icons.check_circle, Colors.green),
                      _buildTargetItem('Unfilled',
                          _targets?['unfilledCustomers'] ?? 0,
                          Icons.cancel, Colors.red),
                      _buildTargetItem('Sellers',
                          _targets?['totalSellers'] ?? 0, Icons.store),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.green.shade50.withOpacity(0.9),
            child: Column(
              children: [
                const Text('Total Commission',
                    style: TextStyle(fontSize: 16)),
                Text(
                  'TZS ${_totalCommission.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.green.shade300 : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Commission by Package',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (_commissions.isEmpty)
            Center(
              child: Text(
                'No commission data.',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            )
          else
            ..._commissions.map((c) => GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: ListTile(
                title: Text(
                  c['packageName'] ?? 'Unknown',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Network: ${c['network'] ?? 'N/A'} | Sales: ${c['count'] ?? 0}',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                trailing: Text(
                  'TZS ${c['totalCommission']?.toStringAsFixed(0) ?? '0'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            )).toList(),
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
        title: const Text('Commissions'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }
}