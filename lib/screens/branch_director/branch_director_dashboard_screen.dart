// lib/screens/branch_director/branch_director_dashboard_screen.dart
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
import 'branch_director_staff_screen.dart';
import 'branch_director_customers_screen.dart';
import 'branch_director_purchases_screen.dart';
import 'branch_director_profile_screen.dart';

class BranchDirectorDashboardScreen extends StatefulWidget {
  const BranchDirectorDashboardScreen({super.key});

  @override
  State<BranchDirectorDashboardScreen> createState() =>
      _BranchDirectorDashboardScreenState();
}

class _BranchDirectorDashboardScreenState
    extends State<BranchDirectorDashboardScreen> {
  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorTitle;
  String? _errorMessage;
  VoidCallback? _retryAction;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
  bool _noBranch = false;
  int _selectedIndex = 0;

  // Dynamic titles for the app bar
  final List<String> _titles = [
    'Branch Director',
    'Staff',
    'Customers',
    'Purchases',
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
      _noBranch = false;
    });
    try {
      final token = await _auth.getToken();
      if (token == null) throw ApiException(statusCode: 401, message: 'Not logged in');

      final profileRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/branch-director/profile',
      );
      final statsRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/branch-director/stats',
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
      } else if (statsRes.statusCode == 400) {
        setState(() => _noBranch = true);
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
    if (_noBranch) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'You are not assigned to any branch.\nPlease contact the administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

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

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFF0A2E5C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileHeader(
              username: _user?['username'] ?? 'Branch Director',
              role: 'Branch Director',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
              greeting: _getGreeting(),
            ),
            const SizedBox(height: 16),
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
                _buildStatCard('Active', _stats?['activeCustomers'] ?? 0,
                    Icons.person_outline, Colors.green),
                _buildStatCard('Staff', _stats?['totalStaff'] ?? 0,
                    Icons.people_outline, Colors.orange),
                _buildStatCard('Purchases', _stats?['totalPurchases'] ?? 0,
                    Icons.shopping_cart, Colors.purple),
                _buildStatCard('Revenue',
                    'TZS ${_stats?['totalRevenue'] ?? 0}', Icons.attach_money,
                    Colors.green),
                _buildStatCard('Tickets', _stats?['openTickets'] ?? 0,
                    Icons.support_agent, Colors.red),
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
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              children: List.generate(6, (_) => const SkeletonStatCard()),
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

  // ─── Build the main body based on selected index ───
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const BranchDirectorStaffScreen(showAppBar: false);
      case 2:
        return const BranchDirectorCustomersScreen(showAppBar: false);
      case 3:
        return const BranchDirectorPurchasesScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  // ─── Show More menu ───
  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Profile', 'icon': Icons.person, 'screen': const BranchDirectorProfileScreen()},
      {'label': 'Settings', 'icon': Icons.settings, 'screen': const SettingsScreen()},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0A1A2B).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300.withOpacity(0.5),
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
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...moreItems.map((item) => Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(item['icon'] as IconData, color: const Color(0xFF0A2E5C)),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => item['screen'] as Widget),
                    );
                  },
                ),
              )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build App Bar ───
  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isHome = _selectedIndex == 0;

    return Container(
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
          const Icon(Icons.business_center, color: Color(0xFF0A2E5C)),
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
          if (isHome)
            const NotificationIcon(),
        ],
      ),
    );
  }

  // ─── Bottom Navigation ───
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1A2B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.people, 'Staff', 1),
              _buildNavItem(Icons.person, 'Customers', 2),
              _buildNavItem(Icons.shopping_bag, 'Purchases', 3),
              _buildMoreButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;
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
              icon,
              color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF0A2E5C) : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: _showMoreMenu,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.more_horiz, color: Colors.grey, size: 24),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}