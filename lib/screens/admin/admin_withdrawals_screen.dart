// lib/screens/admin/admin_withdrawals_screen.dart
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
import '../../models/withdrawal_model.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  final bool showAppBar;

  const AdminWithdrawalsScreen({super.key, this.showAppBar = true});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<WithdrawalRequest> _withdrawals = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  String _filterStatus = 'pending';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabs = ['all', 'pending', 'completed', 'rejected'];
        setState(() {
          _filterStatus = tabs[_tabController.index];
        });
        _fetchWithdrawals();
      }
    });
    _fetchWithdrawals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWithdrawals() async {
    setState(() {
      _isLoading = true;
      _errorTitle = null;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final status = _filterStatus == 'all' ? null : _filterStatus;
      final response = await _api.adminGetWithdrawals(
        context,
        status: status,
        limit: 100,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['withdrawals'] as List? ?? [];
          if (mounted) {
            setState(() {
              _withdrawals = list.map((json) => WithdrawalRequest.fromJson(json)).toList();
              _isLoading = false;
            });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load withdrawals',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchWithdrawals);
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

  Future<void> _markCompleted(WithdrawalRequest withdrawal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Withdrawal #${withdrawal.id}'),
            Text('Amount: TZS ${withdrawal.amount.toStringAsFixed(0)}'),
            Text('User: ${withdrawal.userId}'),
            Text('Phone: ${withdrawal.phone}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Sent'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final response = await _api.adminCompleteWithdrawal(
        context,
        withdrawal.id,
        adminNotes: 'Processed by admin',
      );
      if (response.statusCode == 200) {
        _fetchWithdrawals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal marked as completed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to complete',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markRejected(WithdrawalRequest withdrawal) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Withdrawal #${withdrawal.id}'),
            Text('Amount: TZS ${withdrawal.amount.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final response = await _api.adminRejectWithdrawal(
        context,
        withdrawal.id,
        rejectionReason: reasonController.text.trim(),
      );
      if (response.statusCode == 200) {
        _fetchWithdrawals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal rejected and funds refunded'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to reject',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = _isLoading
        ? ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => const SkeletonListTile(),
    )
        : _errorTitle != null
        ? ErrorView(
      title: _errorTitle!,
      message: _errorMessage!,
      onRetry: _retryAction,
      isFullScreen: false,
    )
        : _withdrawals.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No withdrawal requests'),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchWithdrawals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        itemBuilder: (ctx, i) {
          final w = _withdrawals[i];
          final isPending = w.status == WithdrawalStatus.pending ||
              w.status == WithdrawalStatus.processing;

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
                    Text(
                      'Request #${w.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Chip(
                      label: Text(w.status.displayName),
                      backgroundColor: w.status.color,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: TZS ${w.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Phone: ${w.phone}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Requested: ${_formatDate(w.requestedAt)}',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                if (w.adminNotes != null)
                  Text(
                    'Admin Notes: ${w.adminNotes}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                if (w.rejectionReason != null)
                  Text(
                    'Rejection Reason: ${w.rejectionReason}',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                if (w.completedAt != null)
                  Text(
                    'Completed: ${_formatDate(w.completedAt!)}',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 12),
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _markCompleted(w),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                              : const Text('Mark as Sent'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _markRejected(w),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red),
                          )
                              : const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Rejected'),
                ],
                indicatorColor: const Color(0xFF0A2E5C),
                labelColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Withdrawal Requests'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWithdrawals,
            color: const Color(0xFF0A2E5C),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Completed'),
                Tab(text: 'Rejected'),
              ],
              indicatorColor: const Color(0xFF0A2E5C),
              labelColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}