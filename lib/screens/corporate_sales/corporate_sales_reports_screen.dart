// lib/screens/corporate_sales/corporate_sales_reports_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';  // Provides local Shimmer widget
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class CorporateSalesReportsScreen extends StatefulWidget {
  final bool showAppBar;
  const CorporateSalesReportsScreen({super.key, this.showAppBar = true});

  @override
  State<CorporateSalesReportsScreen> createState() =>
      _CorporateSalesReportsScreenState();
}

class _CorporateSalesReportsScreenState
    extends State<CorporateSalesReportsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _report;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
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
        '${ApiConfig.baseUrl}/api/corporate-sales/reports',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _report = data['report']; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load report',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchReport);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? _buildSkeletonLoading()
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : RefreshIndicator(
      onRefresh: _fetchReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.blue.shade50.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Registration Report',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatRow('Total Customers',
                    _report?['totalCustomers'] ?? 0),
                _buildStatRow('Filled (have purchased)',
                    _report?['filledCustomers'] ?? 0,
                    color: Colors.green),
                _buildStatRow('Unfilled (no purchases)',
                    _report?['unfilledCustomers'] ?? 0,
                    color: Colors.red),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: ((_report?['filledCustomers'] ?? 0) /
                      (_report?['totalCustomers'] ?? 1))
                      .toDouble(),
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.green,
                ),
                const SizedBox(height: 4),
                Text(
                  'Conversion Rate: ${((_report?['filledCustomers'] ?? 0) / (_report?['totalCustomers'] ?? 1) * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: isDark ? Colors.white70
                          : Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.white.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Target Progress',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildTargetRow(
                  'Sales Target',
                  (_report?['salesTarget'] ?? 0).toDouble(),
                  (_report?['salesAchieved'] ?? 0).toDouble(),
                ),
                _buildTargetRow(
                  'Client Acquisition',
                  (_report?['clientTarget'] ?? 0).toDouble(),
                  (_report?['clientAchieved'] ?? 0).toDouble(),
                ),
                _buildTargetRow(
                  'Deal Value Target',
                  (_report?['dealValueTarget'] ?? 0).toDouble(),
                  (_report?['dealValueAchieved'] ?? 0).toDouble(),
                  isCurrency: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            backgroundColor: isDark
                ? const Color(0xFF0A1A2B).withOpacity(0.95)
                : Colors.white.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Performance',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_report?['productPerformance'] == null ||
                    (_report?['productPerformance'] as List).isEmpty)
                  Text(
                    'No product data available.',
                    style: TextStyle(
                        color: isDark ? Colors.white70
                            : Colors.grey.shade600),
                  )
                else
                  ...(_report?['productPerformance'] as List).map(
                          (p) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p['name'] ?? 'Unknown',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87),
                            ),
                            Text(
                              '${p['count']} sales | TZS ${(p['revenue'] ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
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
        title: const Text('Reports'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: body,
    );
  }

  Widget _buildSkeletonLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 200, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 100, color: Colors.grey),
                  Container(height: 14, width: 120, color: Colors.grey),
                  Container(height: 14, width: 140, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 8, width: double.infinity, color: Colors.grey),
                  Container(height: 14, width: 80, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 150, color: Colors.grey),
                  const SizedBox(height: 8),
                  ...List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(width: 80, height: 14, color: Colors.grey),
                            Container(width: 100, height: 14, color: Colors.grey),
                          ],
                        ),
                        Container(height: 6, width: double.infinity, color: Colors.grey),
                        const SizedBox(height: 4),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 150, color: Colors.grey),
                  const SizedBox(height: 8),
                  ...List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 120, height: 14, color: Colors.grey),
                        Container(width: 80, height: 14, color: Colors.grey),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, dynamic value, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade700)),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetRow(String label, double target, double achieved,
      {bool isCurrency = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = target > 0 ? (achieved / target) : 0.0;
    final format = isCurrency
        ? (v) => 'TZS ${v.toStringAsFixed(0)}'
        : (v) => v.toStringAsFixed(0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700)),
            Text(
              '${format(achieved)} / ${format(target)}',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        LinearProgressIndicator(
          value: progress > 1 ? 1.0 : progress,
          backgroundColor: Colors.grey.shade300,
          color: progress >= 1 ? Colors.green : Colors.blue,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}