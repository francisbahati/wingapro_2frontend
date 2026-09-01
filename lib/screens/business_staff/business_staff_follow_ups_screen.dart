// lib/screens/business_staff/business_staff_follow_ups_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/error_view.dart';

class BusinessStaffFollowUpsScreen extends StatefulWidget {
  const BusinessStaffFollowUpsScreen({super.key});

  @override
  State<BusinessStaffFollowUpsScreen> createState() =>
      _BusinessStaffFollowUpsScreenState();
}

class _BusinessStaffFollowUpsScreenState
    extends State<BusinessStaffFollowUpsScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;

  @override
  void initState() {
    super.initState();
    _fetchFollowUps();
  }

  Future<void> _fetchFollowUps() async {
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
        '${ApiConfig.baseUrl}/api/business-staff/field-activities',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final all = data['activities'] ?? [];
          final filtered = all.where((a) =>
          a['followUpAction'] != null &&
              a['followUpAction'].isNotEmpty &&
              a['followUpDate'] != null).toList();
          setState(() { _activities = filtered; _isLoading = false; });
        } else {
          throw ApiException(
            statusCode: response.statusCode,
            message: data['message'] ?? 'Failed to load follow-ups',
          );
        }
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      final info = ErrorHandler.handle(e, onRetry: _fetchFollowUps);
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

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Follow-ups'),
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
        title: const Text('Follow-ups'),
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
          : _activities.isEmpty
          ? const Center(child: Text('No follow‑ups scheduled.'))
          : RefreshIndicator(
        onRefresh: _fetchFollowUps,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _activities.length,
          itemBuilder: (ctx, i) {
            final a = _activities[i];
            final followUpDate =
            DateTime.parse(a['followUpDate']);
            final isOverdue =
            followUpDate.isBefore(DateTime.now());
            return GlassCard(
              backgroundColor: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              child: ListTile(
                leading: Icon(
                  isOverdue ? Icons.warning : Icons.event,
                  color: isOverdue ? Colors.red : Colors.blue,
                ),
                title: Text(
                  a['customerName'],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Action: ${a['followUpAction']}'),
                    Text(
                        'Due: ${DateFormat('dd/MM/yyyy').format(followUpDate)}'),
                  ],
                ),
                trailing: Chip(
                  label: Text(isOverdue ? 'Overdue' : 'Pending'),
                  backgroundColor:
                  isOverdue ? Colors.red : Colors.green,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}