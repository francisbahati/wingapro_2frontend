// lib/screens/showroom/showroom_dashboard_screen.dart
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
import '../../widgets/glass_card.dart';  // ✅ Added import
import '../settings_screen.dart';
import '../notification_screen.dart';
import 'showroom_customers_screen.dart';
import 'showroom_register_customer_screen.dart';
import 'showroom_sell_package_screen.dart';
import 'showroom_sales_screen.dart';
import 'showroom_payments_screen.dart';
import 'showroom_refunds_screen.dart';
import 'showroom_complaints_screen.dart';
import 'showroom_profile_screen.dart';

class ShowroomDashboardScreen extends StatefulWidget {
  const ShowroomDashboardScreen({super.key});

  @override
  State<ShowroomDashboardScreen> createState() =>
      _ShowroomDashboardScreenState();
}

class _ShowroomDashboardScreenState extends State<ShowroomDashboardScreen> {
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
    'Showroom Dashboard',
    'Register',
    'Customers',
    'Sell',
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
        '${ApiConfig.baseUrl}/api/showroom/profile',
      );
      final statsRes = await _api.get(
        context,
        '${ApiConfig.baseUrl}/api/showroom/stats',
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
                children: List.generate(4, (_) => const SkeletonStatCard()),
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
              username: _user?['username'] ?? 'Showroom Staff',
              role: 'Showroom',
              email: _user?['email'] ?? '',
              phone: _user?['phone'] ?? '',
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
                _buildStatCard('Active', _stats?['activeCustomers'] ?? 0,
                    Icons.person_outline, Colors.green),
                _buildStatCard('Sales', _stats?['totalSales'] ?? 0,
                    Icons.shopping_cart, Colors.orange),
                _buildStatCard('Revenue', 'TZS ${_stats?['totalRevenue'] ?? 0}',
                    Icons.attach_money, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            // Cash to Deposit Card
            GlassCard(
              backgroundColor: isDark
                  ? Colors.red.shade900.withOpacity(0.3)
                  : Colors.red.shade50.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash to Deposit',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Physical cash collected from sales',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '- TZS ${(_stats?['cashCollected'] ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
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

  // ─── Show More menu ───
  void _showMoreMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final moreItems = [
      {'label': 'Sales', 'icon': Icons.shopping_bag, 'screen': const ShowroomSalesScreen()},
      {'label': 'Payments', 'icon': Icons.payment, 'screen': const ShowroomPaymentsScreen()},
      {'label': 'Refunds', 'icon': Icons.currency_exchange, 'screen': const ShowroomRefundsScreen()},
      {'label': 'Complaints', 'icon': Icons.support_agent, 'screen': const ShowroomComplaintsScreen()},
      {'label': 'Profile', 'icon': Icons.person, 'screen': const ShowroomProfileScreen()},
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
              _buildNavItem(Icons.person_add, 'Register', 1),
              _buildNavItem(Icons.people, 'Customers', 2),
              _buildNavItem(Icons.sell, 'Sell', 3),
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

  // ─── Body based on selected index ───
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ShowroomRegisterCustomerScreen(showAppBar: false);
      case 2:
        return const ShowroomCustomersScreen(showAppBar: false);
      case 3:
        return const ShowroomSellPackageScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorTitle != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        body: Column(
          children: [
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
                  const Icon(Icons.store, color: Color(0xFF0A2E5C)),
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
            Expanded(
              child: ErrorView(
                title: _errorTitle!,
                message: _errorMessage!,
                onRetry: _retryAction,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      body: Column(
        children: [
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
                const Icon(Icons.store, color: Color(0xFF0A2E5C)),
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
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}