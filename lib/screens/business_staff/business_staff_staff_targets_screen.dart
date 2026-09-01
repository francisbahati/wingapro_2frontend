// lib/screens/business_staff/business_staff_staff_targets_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class BusinessStaffStaffTargetsScreen extends StatefulWidget {
  const BusinessStaffStaffTargetsScreen({super.key});

  @override
  State<BusinessStaffStaffTargetsScreen> createState() =>
      _BusinessStaffStaffTargetsScreenState();
}

class _BusinessStaffStaffTargetsScreenState
    extends State<BusinessStaffStaffTargetsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _staffTargets = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchStaffTargets();
  }

  Future<void> _fetchStaffTargets() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/staff-targets',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() { _staffTargets = data['staffTargets']; _isLoading = false; });
          }
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load staff targets',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchStaffTargets);
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
          title: const Text('Staff Targets'),
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
        title: const Text('Staff Targets'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
      ),
      body: _isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonListTile(),
      )
          : _staffTargets.isEmpty
          ? const Center(
          child: Text('No staff targets data available.'))
          : RefreshIndicator(
        onRefresh: _fetchStaffTargets,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _staffTargets.length,
          itemBuilder: (ctx, i) {
            final s = _staffTargets[i];
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
              child: ExpansionTile(
                title: Text(
                  s['username'] ?? 'Unknown',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Customers: ${s['totalCustomers']} | Filled: ${s['filledCustomers']} | Unfilled: ${s['unfilledCustomers']}',
                  style: TextStyle(
                    color: isDark ? Colors.white70
                        : Colors.grey.shade700,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Activities: ${s['totalActivities']}',
                          style: TextStyle(
                            color: isDark ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          'Outcomes: Bought ${s['outcomes']?['bought'] ?? 0}, Interested ${s['outcomes']?['interested'] ?? 0}, Not Interested ${s['outcomes']?['not_interested'] ?? 0}',
                          style: TextStyle(
                            color: isDark ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
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