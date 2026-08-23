// lib/screens/finance/finance_reports_screen.dart
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

class FinanceReportsScreen extends StatefulWidget {
  final bool showAppBar;
  const FinanceReportsScreen({super.key, this.showAppBar = true});

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _financialReport;
  List<dynamic> _corporateReport = [];
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');
      String financialUrl = '${ApiConfig.baseUrl}/api/finance/reports/financial';
      final query = [];
      if (_startDate != null) {
        query.add(
            'startDate=${_startDate!.toIso8601String().split('T').first}');
      }
      if (_endDate != null) {
        query.add('endDate=${_endDate!.toIso8601String().split('T').first}');
      }
      if (query.isNotEmpty) financialUrl += '?${query.join('&')}';

      String corpUrl = '${ApiConfig.baseUrl}/api/finance/reports/corporate';
      if (query.isNotEmpty) corpUrl += '?${query.join('&')}';

      final finResp = await _api.get(context, financialUrl);
      final corpResp = await _api.get(context, corpUrl);

      if (finResp.statusCode == 200 && corpResp.statusCode == 200) {
        final finData = jsonDecode(finResp.body);
        final corpData = jsonDecode(corpResp.body);
        if (finData['success'] && corpData['success']) {
          setState(() {
            _financialReport = finData['report'];
            _corporateReport = corpData['corporateReport'] ?? [];
            _isLoading = false;
          });
        } else {
          throw ApiException(
            statusCode: 400,
            message: 'Failed to load reports',
          );
        }
      } else {
        throw ApiException(
          statusCode: 500,
          message: 'Server error',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchReports);
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _fetchReports();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _fetchReports();
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _fetchReports();
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
      onRefresh: _fetchReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18,
                            color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _startDate == null
                              ? 'Start Date'
                              : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                          style: TextStyle(
                            color: _startDate == null
                                ? Colors.grey
                                : (isDark ? Colors.white
                                : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18,
                            color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _endDate == null
                              ? 'End Date'
                              : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                          style: TextStyle(
                            color: _endDate == null
                                ? Colors.grey
                                : (isDark ? Colors.white
                                : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearDates,
                tooltip: 'Clear dates',
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_financialReport != null)
            GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.95)
                  : Colors.white.withOpacity(0.9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Summary',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Total Revenue',
                      _financialReport?['totalRevenue'] ?? 0),
                  _buildSummaryRow('Admin Profit',
                      _financialReport?['totalAdminProfit'] ?? 0),
                  _buildSummaryRow('Seller Payouts',
                      _financialReport?['totalSellerPayout'] ?? 0),
                  _buildSummaryRow('Total Purchases',
                      _financialReport?['totalPurchases'] ?? 0),
                  const SizedBox(height: 8),
                  const Text('Network Breakdown',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(_financialReport?['networkBreakdown'] as List? ??
                      [])
                      .map((n) => Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 2),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(n['network'] ?? 'Unknown'),
                        Text(
                            'TZS ${n['revenue']?.toStringAsFixed(0) ?? '0'}'),
                      ],
                    ),
                  ))
                      .toList(),
                  const SizedBox(height: 8),
                  const Text('Package Breakdown',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(_financialReport?['packageBreakdown'] as List? ??
                      [])
                      .map((p) => Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 2),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${p['packageName']} (${p['count']} sales)'),
                        Text(
                            'TZS ${p['revenue']?.toStringAsFixed(0) ?? '0'}'),
                      ],
                    ),
                  ))
                      .toList(),
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
                  'Corporate Revenue by Branch',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_corporateReport.isEmpty)
                  Text(
                    'No data',
                    style: TextStyle(
                        color: isDark ? Colors.white70
                            : Colors.grey.shade600),
                  )
                else
                  ..._corporateReport.map((b) => Column(
                    children: [
                      ListTile(
                        title: Text(
                          b['branchName'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Manager: ${b['manager']} | Customers: ${b['totalCustomers']} (Filled: ${b['filledCustomers']}, Unfilled: ${b['unfilledCustomers']})',
                          style: TextStyle(
                            color: isDark ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            Text(
                              'TZS ${b['revenue']?.toStringAsFixed(0) ?? '0'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              'Profit: TZS ${b['adminProfit']?.toStringAsFixed(0) ?? '0'}',
                              style: TextStyle(
                                color: isDark ? Colors.white60
                                    : Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  )).toList(),
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
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade800.withOpacity(0.5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Shimmer(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Start Date',
                        style: TextStyle(color: Colors.transparent)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade800.withOpacity(0.5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Shimmer(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('End Date',
                        style: TextStyle(color: Colors.transparent)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: null,
            ),
          ],
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
                  ...List.generate(4, (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 80, height: 14, color: Colors.grey),
                        Container(width: 100, height: 14, color: Colors.grey),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 120, color: Colors.grey),
                  ...List.generate(2, (_) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 60, height: 12, color: Colors.grey),
                        Container(width: 80, height: 12, color: Colors.grey),
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
                  ...List.generate(2, (_) => ListTile(
                    title: Container(height: 16, width: 100, color: Colors.grey),
                    subtitle: Container(height: 12, width: 150, color: Colors.grey),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(height: 14, width: 60, color: Colors.grey),
                        Container(height: 12, width: 80, color: Colors.grey),
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

  Widget _buildSummaryRow(String label, dynamic value) {
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
            value is double ? 'TZS ${value.toStringAsFixed(0)}' : value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}