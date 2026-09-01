// lib/screens/business_staff/business_staff_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/notification_icon.dart';
import '../settings_screen.dart';
import 'business_staff_customers_screen.dart';
import 'business_staff_register_customer_screen.dart';
import 'business_staff_field_activities_screen.dart';
import 'business_staff_profile_screen.dart';
import 'business_staff_sales_screen.dart';
import 'business_staff_follow_ups_screen.dart';
// Removed unused imports

class BusinessStaffDashboardScreen extends StatefulWidget {
  const BusinessStaffDashboardScreen({super.key});

  @override
  State<BusinessStaffDashboardScreen> createState() =>
      _BusinessStaffDashboardScreenState();
}

class _BusinessStaffDashboardScreenState
    extends State<BusinessStaffDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  final List<String> _titles = [
    'Business Staff',
    'Register',
    'Customers',
    'Field Act.',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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

      final profileRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/business-staff/profile',
      );
      final statsRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/business-staff/stats',
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        if (data['success'] == true) {
          setState(() => _user = data['user']);
        }
      }
      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        if (data['success'] == true) {
          setState(() => _stats = data['stats']);
        }
      }
      setState(() => _isLoading = false);
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildHomeContent() {
    if (_errorTitle != null) {
      return ErrorView(
        title: _errorTitle!,
        message: _errorMessage!,
        onRetry: _retryAction,
        isFullScreen: false,
      );
    }

    if (_isLoading) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SkeletonProfile(),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: List.generate(8, (_) => const SkeletonStatCard()),
              ),
            ],
          ),
        ),
      );
    }

    final branch = _user?['Branch']?['name'] ?? '';

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFF0A2E5C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeader(
              username: _user?['username'] ?? 'Business Staff',
              role: 'Business Staff',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
              greeting: _getGreeting(),
              branch: branch.isNotEmpty ? branch : null,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: [
                _buildStatCard('Customers', _stats?['totalCustomers'] ?? 0,
                    Icons.people, Colors.blue),
                _buildStatCard('Filled', _stats?['filledCustomers'] ?? 0,
                    Icons.check_circle, Colors.green),
                _buildStatCard('Unfilled', _stats?['unfilledCustomers'] ?? 0,
                    Icons.cancel, Colors.red),
                _buildStatCard('Activities', _stats?['totalActivities'] ?? 0,
                    Icons.location_on, Colors.orange),
                _buildStatCard('Bought', _stats?['outcomes']?['bought'] ?? 0,
                    Icons.trending_up, Colors.purple),
                _buildStatCard('Interested',
                    _stats?['outcomes']?['interested'] ?? 0,
                    Icons.trending_flat, Colors.amber),
                _buildStatCard('Not Interested',
                    _stats?['outcomes']?['not_interested'] ?? 0,
                    Icons.trending_down, Colors.grey),
                _buildStatCard('Revenue',
                    'TZS ${_stats?['totalRevenue'] ?? 0}', Icons.attach_money,
                    Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
    final displayValue = value is String ? value : value.toString();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.grey.shade300.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build Body Based on Selected Index ───
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const BusinessStaffRegisterCustomerScreen();
      case 2:
        return const BusinessStaffCustomersScreen();
      case 3:
        return const BusinessStaffFieldActivitiesScreen();
      default:
        return _buildHomeContent();
    }
  }

  // ─── Show More Menu ───
  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildMoreItem(ctx, 'Sales', Icons.shopping_bag, const BusinessStaffSalesScreen()),
              _buildMoreItem(ctx, 'Follow-ups', Icons.notifications_active, const BusinessStaffFollowUpsScreen()),
              _buildMoreItem(ctx, 'Profile', Icons.person, const BusinessStaffProfileScreen()),
              _buildMoreItem(ctx, 'Settings', Icons.settings, const SettingsScreen()),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreItem(BuildContext ctx, String label, IconData icon, Widget screen) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0A2E5C)),
        title: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        onTap: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }

  // ─── Bottom Navigation Bar ───
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      {'label': 'Home', 'icon': Icons.home, 'index': 0},
      {'label': 'Register', 'icon': Icons.person_add, 'index': 1},
      {'label': 'Customers', 'icon': Icons.people, 'index': 2},
      {'label': 'Field Act.', 'icon': Icons.location_on, 'index': 3},
      {'label': 'More', 'icon': Icons.more_horiz, 'index': 4},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final index = item['index'] as int;
              final isSelected = index == _selectedIndex;
              if (item['label'] == 'More') {
                return Expanded(
                  child: GestureDetector(
                    onTap: _showMoreMenu,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.more_horiz,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'More',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0A2E5C),
        actions: [
          const NotificationIcon(),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}