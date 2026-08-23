// lib/screens/business_staff/business_staff_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/api_config.dart';
import '../../services/error_handler.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/role_navigation.dart';
import '../../widgets/skeleton_loading.dart';
import '../../widgets/error_view.dart';
import '../../widgets/notification_icon.dart';
import '../settings_screen.dart';
import '../notification_screen.dart';
import 'business_staff_customers_screen.dart';
import 'business_staff_register_customer_screen.dart';
import 'business_staff_field_activities_screen.dart';
import 'business_staff_register_seller_screen.dart';
import 'business_staff_staff_targets_screen.dart';
import 'business_staff_follow_ups_screen.dart';
import 'business_staff_profile_screen.dart';
import 'business_staff_sales_screen.dart';

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
      setState(() {
        _errorTitle = info.title;
        _errorMessage = info.message;
        _retryAction = info.action;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return ErrorView(
        title: _errorTitle!,
        message: _errorMessage!,
        onRetry: _retryAction,
        isFullScreen: false,
      );
    }

    if (_isLoading) {
      return _buildLoadingState();
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
            // ❌ BannerCarousel removed
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SkeletonProfile(),
            const SizedBox(height: 16),
            // SkeletonBannerCarousel removed
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

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = value is String ? value : value.toString();
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
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
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Navigation ───
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      MoreItem(
        label: 'Sales',
        icon: Icons.shopping_bag,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessStaffSalesScreen()),
        ),
      ),
      MoreItem(
        label: 'Follow-ups',
        icon: Icons.notifications_active,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessStaffFollowUpsScreen()),
        ),
      ),
      MoreItem(
        label: 'Profile',
        icon: Icons.person,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessStaffProfileScreen()),
        ),
      ),
      MoreItem(
        label: 'Settings',
        icon: Icons.settings,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ];

    return RoleNavigation(
      items: [
        NavItem(label: 'Home', icon: Icons.home, screen: _buildHomeContent()),
        NavItem(
          label: 'Register',
          icon: Icons.person_add,
          screen: const BusinessStaffRegisterCustomerScreen(),
        ),
        NavItem(
          label: 'Customers',
          icon: Icons.people,
          screen: const BusinessStaffCustomersScreen(),
        ),
        NavItem(
          label: 'Field Act.',
          icon: Icons.location_on,
          screen: const BusinessStaffFieldActivitiesScreen(),
        ),
      ],
      moreItems: moreItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: Column(
        children: [
          // Fixed App Bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0A1A2B).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF0A2E5C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _titles[_selectedIndex],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0A2E5C),
                    ),
                  ),
                ),
                const NotificationIcon(),
              ],
            ),
          ),
          // Body with bottom navigation
          Expanded(
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }
}